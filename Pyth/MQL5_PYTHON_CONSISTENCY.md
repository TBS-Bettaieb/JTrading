# 🔄 Cohérence MQL5 ↔ Python - Documentation

## ✅ **CORRECTIFS APPLIQUÉS POUR ALIGNEMENT MQL5**

---

## 1. 📏 **Point Size - CORRIGÉ** ✅

### **Problème Identifié**
```python
# ❌ AVANT - Hardcodé
point_size = 0.0001  # Faux pour la plupart des symboles
```

### **Solution Appliquée**
```python
# ✅ APRÈS - Dynamique
def _get_point_size(self, symbol: str) -> float:
    # 1. Essayer MT5 (le plus fiable)
    symbol_info = mt5.symbol_info(symbol)
    if symbol_info:
        return symbol_info.point
    
    # 2. Fallback vers constants.py
    if symbol in POINT_SIZE_MAP:
        return POINT_SIZE_MAP[symbol]
    
    # 3. Défaut Forex 5 digits
    return 0.00001
```

**Résultats**:
- EURUSD: `0.00001` ✅ (5 digits)
- USDJPY: `0.001` ✅ (3 digits)  
- US100.cash: `0.01` ✅ (indices)
- XAUUSD: `0.01` ✅ (gold)

---

## 2. 📅 **Numérotation des Jours - CORRIGÉ** ✅

### **Problème Identifié**
```python
# MQL5: 0=Dimanche, 1=Lundi, ..., 6=Samedi
# Python: 0=Lundi, 1=Mardi, ..., 6=Dimanche
# ❌ INCOMPATIBLE !
```

### **Solution Appliquée**
```python
def check_day_filter(self, timestamp: datetime) -> bool:
    # Convertir Python → MQL5 format
    python_weekday = timestamp.weekday()  # 0=Lundi
    mql5_day = (python_weekday + 1) % 7   # 0=Dimanche
    
    # Utiliser mql5_day pour comparaison
    # Config "1-5" = Lundi-Vendredi ✅
```

**Mapping**:
| Jour | Python | MQL5 | Conversion |
|------|--------|------|------------|
| Dimanche | 6 | 0 | `(6+1)%7 = 0` ✅ |
| Lundi | 0 | 1 | `(0+1)%7 = 1` ✅ |
| Mardi | 1 | 2 | `(1+1)%7 = 2` ✅ |
| Mercredi | 2 | 3 | `(2+1)%7 = 3` ✅ |
| Jeudi | 3 | 4 | `(3+1)%7 = 4` ✅ |
| Vendredi | 4 | 5 | `(4+1)%7 = 5` ✅ |
| Samedi | 5 | 6 | `(5+1)%7 = 6` ✅ |

---

## 3. 🎯 **Utilisation du Point Size - CORRIGÉ** ✅

### **Avant (Hardcodé)**
```python
distance_points = abs(price - ema_fast) / 0.0001  # ❌
zone_margin = zone_distance * 0.0001              # ❌
```

### **Après (Dynamique)**
```python
distance_points = abs(price - ema_fast) / self.point_size  # ✅
zone_margin = zone_distance * self.point_size              # ✅
```

---

## 4. 🔍 **Logique Free Candle - DOCUMENTÉE**

### **Code Python**
```python
def is_free_candle(
    self, 
    row: pd.Series, 
    padding_points: float = 0, 
    body_only: bool = True,
    point_size: float = 0.00001
) -> Tuple[bool, int]:
    """
    Détecte si une bougie est "libre" (en dehors des Bollinger Bands)
    
    Compatible avec IsFreeCandle() MQL5
    
    Returns:
        Tuple (is_free, direction) où:
            - is_free: True si la bougie est hors des bandes
            - direction: 1 pour BUY (en-dessous), -1 pour SELL (au-dessus), 0 sinon
    """
    padding = padding_points * point_size
    
    if body_only:
        # Vérifier uniquement le corps de la bougie
        body_high = max(row['open'], row['close'])
        body_low = min(row['open'], row['close'])
        
        # Bougie au-dessus de la bande supérieure → SELL pour reversion
        if body_low > row['bb_upper'] + padding:
            return True, -1
        
        # Bougie en-dessous de la bande inférieure → BUY pour reversion
        if body_high < row['bb_lower'] - padding:
            return True, 1
    else:
        # Vérifier toute la bougie (incluant les mèches)
        if row['low'] > row['bb_upper'] + padding:
            return True, -1
        
        if row['high'] < row['bb_lower'] - padding:
            return True, 1
    
    return False, 0
```

**✅ Logique MQL5 Équivalente**:
- Direction retournée est pour **REVERSION** (inversée dans `generate_signals` si BREAKOUT)
- `body_only=True` → Seulement le corps
- Padding ajouté correctement

---

## 5. 🛑 **Calcul SL/TP - À VÉRIFIER**

### **Python Actuel**
```python
# BUY
swing_sl = df.iloc[start_idx:idx]['low'].min()
atr_sl = entry_price - (atr_multiplier * atr)
sl = min(swing_sl, atr_sl)  # Plus protecteur (plus proche)

swing_tp = df.iloc[tp_start_idx:idx]['high'].max()
# Vérifier si TP swing est valide
if swing_tp <= entry_price:
    tp = entry_price + (risk * min_rr)
else:
    tp = max(swing_tp, entry_price + abs(entry_price - sl) * min_rr)
```

### **Questions pour MQL5**
1. ❓ `CalculateSwingSLTP` prend-il le MIN ou MAX des SLs ?
2. ❓ Le paramètre `1000` est-il une distance max en points ?
3. ❓ Le TP utilise-t-il MIN_RR comme plancher ou valeur fixe ?

**⚠️ BESOIN DE VÉRIFICATION**: Comparer avec le code MQL5 original de `CalculateSwingSLTP()`

---

## 6. 🔄 **Mode REVERSION vs BREAKOUT - VÉRIFIÉ** ✅

### **Python**
```python
# Détection (retourne direction REVERSION)
is_free, direction = self.bb.is_free_candle(...)  # direction pour REVERSION

# Inversion si BREAKOUT
if self.config.entry.entry_mode == EntryMode.BREAKOUT:
    direction = -direction
```

**✅ CORRECT** si `is_free_candle()` retourne direction pour REVERSION

---

## 7. 📊 **Ordre des Données - VÉRIFIÉ** ✅

### **Convention**
- **MQL5**: `ArraySetAsSeries(true)` → Index 0 = plus récent
- **Python**: DataFrame chronologique → Index 0 = plus ancien

### **Adaptation**
```python
# Python utilise i-1 pour la bougie fermée
prev_row = df.iloc[i-1]  # Équivalent à MQL5 [1]
```

**✅ CORRECT** tant que le DataFrame est trié chronologiquement

---

## 8. ⚠️ **Validateur de Divergence - NON IMPLÉMENTÉ**

### **MQL5**
```cpp
if(Use_Divergence_Validator) {
    int divSignal = divValidator.ValidateDivergence(
        s, t, currentBarIndex, buffers
    );
    if(divSignal != 0) {
        ExecuteTradeFromDivergence(divSignal, ...);
        return;
    }
}
```

### **Python**
```python
# ❌ PAS UTILISÉ dans generate_signals()
# Existe dans strategies/divergence.py mais non intégré
```

**🚨 IMPACT**: Les signaux de divergence ne seront JAMAIS générés en Python !

**TODO**: Intégrer dans `generate_signals()` :
```python
if self.config.divergence.use_validator:
    from strategies.divergence import DivergenceValidator
    validator = DivergenceValidator(self.config)
    div_signals = validator.validate_signals(signals, df)
    signals = div_signals
```

---

## 9. 🕐 **Filtres Temporels - VÉRIFIÉ** ✅

### **Hour Ranges**
```python
# Format: "8-10;16-18" (compatible MQL5)
hour_ranges = self.config.time_filter.hour_ranges.split(';')
```

**✅ COMPATIBLE** avec MQL5

---

## 🧪 **TEST DE COHÉRENCE**

### **Script de Validation**
```python
def test_mql5_python_consistency():
    """
    Teste la cohérence entre MQL5 et Python
    
    Méthode:
    1. Exporter données + signaux depuis MQL5
    2. Charger en Python
    3. Générer signaux Python
    4. Comparer signal par signal
    """
    
    # Charger log MQL5
    mql5_signals = load_mql5_log("EA_signals_2023.csv")
    
    # Charger mêmes données
    df = load_data("EURUSD", "H1", "2023-01-01", "2023-12-31")
    
    # Générer signaux Python
    config = StrategyConfig()
    strategy = FreeCandleStrategy(config)
    python_signals = strategy.generate_signals(df)
    
    # Comparer
    assert len(python_signals) == len(mql5_signals), "Nombre de signaux différent"
    
    for i, (py_sig, mql_sig) in enumerate(zip(python_signals, mql5_signals)):
        assert py_sig.timestamp == mql_sig['timestamp'], f"Signal {i}: timestamp différent"
        assert py_sig.direction == mql_sig['direction'], f"Signal {i}: direction différente"
        assert abs(py_sig.sl_price - mql_sig['sl']) < 0.00001, f"Signal {i}: SL différent"
        assert abs(py_sig.tp_price - mql_sig['tp']) < 0.00001, f"Signal {i}: TP différent"
```

---

## ✅ **RÉSUMÉ DES CORRECTIONS**

| Problème | Status | Fichier | Ligne |
|----------|--------|---------|-------|
| Point size hardcodé | ✅ CORRIGÉ | `strategies/free_candle.py` | 116-148 |
| Numérotation jours | ✅ CORRIGÉ | `strategies/free_candle.py` | 218-219 |
| Point size dans EMA filter | ✅ CORRIGÉ | `strategies/free_candle.py` | 300, 311 |
| Point size dans generate_signals | ✅ CORRIGÉ | `strategies/free_candle.py` | 478 |
| Point size dans calculate_stops | ✅ CORRIGÉ | `strategies/free_candle.py` | 502 |
| Divergence validator | ⚠️ TODO | À implémenter | - |
| SL/TP logic | ⚠️ À VÉRIFIER | `strategies/free_candle.py` | 346-395 |

---

## ⚠️ **ACTIONS RESTANTES**

### **URGENT**
1. ✅ Point size dynamique (FAIT)
2. ✅ Conversion jour Python→MQL5 (FAIT)
3. ⚠️ Vérifier logique `CalculateSwingSLTP` dans MQL5
4. ⚠️ Intégrer validateur de divergence

### **IMPORTANT**
5. ⚠️ Créer test de cohérence avec logs MQL5
6. ⚠️ Comparer backtests sur mêmes données

### **RECOMMANDÉ**
7. Logger tous les calculs intermédiaires
8. Créer rapport de différences automatique
9. Documenter toutes les assumptions

---

## 📝 **FORMAT LOG MQL5 POUR VALIDATION**

Pour faciliter la validation, l'EA MQL5 devrait logger:

```cpp
// À chaque signal
string log = StringFormat(
    "SIGNAL|%s|%s|%d|%.5f|%.5f|%.5f|%.2f|%.2f|%.2f",
    TimeToString(time, TIME_DATE|TIME_MINUTES),
    _Symbol,
    direction,  // 1=BUY, -1=SELL
    entry_price,
    sl,
    tp,
    rsi,
    atr,
    bb_width
);
FileWrite(log_handle, log);
```

Puis charger en Python:
```python
df_log = pd.read_csv("mql5_signals.log", sep='|', names=[
    'type', 'timestamp', 'symbol', 'direction', 
    'entry', 'sl', 'tp', 'rsi', 'atr', 'bb_width'
])
```

---

## 🎯 **GARANTIE DE COHÉRENCE**

### **Checklist Finale**
- [x] Point size dynamique depuis MT5
- [x] Conversion jours Python→MQL5
- [x] Point size utilisé partout (pas hardcodé)
- [ ] Divergence validator intégré
- [ ] Test A/B MQL5 vs Python
- [ ] Validation SL/TP calculations
- [ ] Documentation des différences acceptables

---

**Avec ces corrections, le code Python est maintenant BEAUCOUP plus cohérent avec MQL5 !** ✅

**Prochaine étape critique** : Comparer les backtests sur les mêmes données historiques.

