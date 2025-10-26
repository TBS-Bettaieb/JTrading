# 🏗️ Architecture Scalping Robot v2.0

## 📊 Diagramme d'Architecture Multi-Symboles

```
┌─────────────────────────────────────────────────────────────────┐
│                    Scalping Robot v2.0                         │
│                     (Fichier Principal)                        │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                        OnInit()                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │ Parse Symbols   │  │ Validate Data   │  │ Create Traders  │ │
│  │                 │  │                 │  │                 │ │
│  │ • SymbolsList   │  │ • Historical    │  │ • CSymbolTrader │ │
│  │ • Market Watch  │  │ • Spreads       │  │ • Magic Numbers │ │
│  │ • Validation    │  │ • Liquidity     │  │ • Risk Calc     │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                         OnTick()                                │
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │ EURUSD      │  │ GBPUSD      │  │ USDJPY      │             │
│  │ Trader      │  │ Trader      │  │ Trader      │     ...     │
│  │             │  │             │  │             │             │
│  │ • OnTick()  │  │ • OnTick()  │  │ • OnTick()  │             │
│  │ • TrailStop │  │ • TrailStop │  │ • TrailStop │             │
│  │ • Orders    │  │ • Orders    │  │ • Orders    │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    UpdateChartInfo()                            │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐                     │
│  │ Global Status   │  │ Symbol Details  │                     │
│  │                 │  │                 │                     │
│  │ • Total P/L     │  │ • Per Symbol    │                     │
│  │ • Positions     │  │ • Status Info   │                     │
│  │ • Active Count  │  │ • Individual P/L│                     │
│  └─────────────────┘  └─────────────────┘                     │
└─────────────────────────────────────────────────────────────────┘
```

## 🔧 Composants Principaux

### 1. **Scalping Robot.mq5** (Fichier Principal)
```cpp
// Variables Globales
CSymbolTrader* symbolTraders[] = NULL;  // Array de traders
string symbols[];                       // Liste des symboles
int totalSymbols = 0;                   // Nombre total de symboles

// Fonctions Principales
OnInit()     // Initialisation multi-symboles
OnTick()     // Traitement par symbole
OnDeinit()   // Nettoyage mémoire
UpdateChartInfo() // Affichage multi-symboles
```

### 2. **CSymbolTrader** (Classe par Symbole)
```cpp
class CSymbolTrader
{
private:
    string m_symbol;              // Symbole (EURUSD, GBPUSD, etc.)
    int m_magicNumber;            // Magic unique (298347, 298447, etc.)
    double m_riskPercent;         // Risque par symbole
    // ... autres paramètres
    
public:
    void OnTick();                // Logique de trading
    void TrailStop();             // Trailing stop
    void CloseAllOrders();        // Fermeture positions
    string GetStatusInfo();       // Info pour affichage
    double GetTotalProfit();      // Profit total
};
```

### 3. **JT_SymbolManager** (Utilitaires)
```cpp
// Fonctions de Parsing
int ParseSymbolsList(string list, string &symbols[]);
bool ValidateSymbol(string symbol);
int GetSymbolsFromMarketWatch(string &symbols[]);

// Fonctions de Calcul
int GenerateMagicNumber(int base, int index);
double CalculateRiskPerSymbol(double total, int count);
string GetGlobalSymbolsStatus(string &symbols[], CSymbolTrader* &traders[]);
```

## 🔄 Flux de Données

### Initialisation
```
1. Parse SymbolsList → Array de symboles validés
2. Calculate RiskPerSymbol → Risque divisé par symbole
3. Create CSymbolTrader[] → Un trader par symbole
4. Initialize ChartManager → Affichage multi-symboles
```

### Trading Loop
```
OnTick() {
    for each symbolTraders[i] {
        symbolTraders[i].OnTick()    // Logique trading
        symbolTraders[i].TrailStop() // Trailing stops
    }
    UpdateChartInfo()                // Mise à jour affichage
}
```

### Gestion des Positions
```
Chaque CSymbolTrader gère indépendamment:
├── Positions BUY/SELL
├── Ordres en attente
├── Trailing stops
├── Calcul des lots
└── Statistiques
```

## 📊 Exemple de Configuration

### Input Configuration
```cpp
SymbolsList = "EURUSD,GBPUSD,USDJPY"  // 3 symboles
RiskPercent = 1.5                      // 1.5% total
BaseMagic = 298347                     // Magic de base
```

### Résultat Automatique
```cpp
EURUSD: Magic=298347, Risk=0.5% (1.5% ÷ 3)
GBPUSD: Magic=298447, Risk=0.5% (1.5% ÷ 3)  
USDJPY: Magic=298547, Risk=0.5% (1.5% ÷ 3)
```

## 🎯 Avantages de l'Architecture

### 1. **Modularité**
- Chaque symbole est indépendant
- Facile d'ajouter/supprimer des symboles
- Code réutilisable et maintenable

### 2. **Sécurité**
- Magic numbers uniques par symbole
- Gestion mémoire automatique
- Validation des symboles

### 3. **Performance**
- Traitement parallèle par symbole
- Optimisation des mises à jour graphiques
- Gestion intelligente des ressources

### 4. **Flexibilité**
- Configuration simple ou Market Watch
- Répartition automatique du risque
- Paramètres communs ou individuels

## 🚀 Utilisation

### Configuration Simple
```cpp
// Dans MetaTrader 5
SymbolsList = "EURUSD,GBPUSD,USDJPY"
RiskPercent = 2.0
BaseMagic = 298347
```

### Configuration Avancée
```cpp
// Utiliser tous les symboles du Market Watch
UseAllSymbols = true
RiskPercent = 5.0  // Divisé automatiquement
```

## 📈 Résultats Attendus

### Affichage Console
```
═══════════════════════════════════════
🚀 Initializing Scalping Robot v2.0
═══════════════════════════════════════
📊 Using custom symbols list: 3 symbols
💰 Risk per symbol: 0.67% (Total: 2.0%)
✅ Initialization completed successfully!
📈 Trading 3 symbols simultaneously
═══════════════════════════════════════
```

### Affichage Graphique
```
Status: ACTIVE | GLOBAL: Symbols: 2/3 | Positions: 4 | P/L: +15.50

━━━ SYMBOL DETAILS ━━━
EURUSD: ACTIVE | Pos: 2 (B:1 S:1) | P/L: +8.25
GBPUSD: ACTIVE | Pos: 2 (B:2 S:0) | P/L: +7.25
USDJPY: IDLE
```

---

*Architecture refactorisée pour une scalabilité maximale et une maintenance simplifiée.*
