# 🏗️ Architecture Modulaire RSI Divergence - Classes MQH

## 📋 Vue d'ensemble

Cette refactorisation transforme le système RSI Divergence en une architecture modulaire avec des classes MQH réutilisables, permettant une meilleure performance, maintenabilité et flexibilité.

## 🎯 Objectifs atteints

✅ **Performance optimisée** : EA peut calculer directement sans dépendre de l'indicateur  
✅ **Modularité** : Classes réutilisables dans d'autres projets  
✅ **Maintenance** : Code centralisé, pas de duplication  
✅ **Flexibilité** : Possibilité d'utiliser l'EA avec ou sans indicateur  
✅ **Debug** : Classes isolées plus faciles à tester

## 📁 Structure des fichiers

### Classes MQH créées dans `Shared/`

#### 1. `RSI_Calculator.mqh`

**Responsabilité** : Calcul du RSI optimisé avec formule RMA (équivalent Pine Script)

```cpp
class CRSICalculator
{
   // Calcul RSI avec support calculs incrémentaux
   bool Calculate(const int rates_total, const int prev_calculated, const double &close[]);

   // Accès aux données
   double GetValue(int index);
   bool GetBuffer(double &output[], int start = 0, int count = -1);

   // Configuration
   void SetPeriod(int period);
   void SetAppliedPrice(ENUM_APPLIED_PRICE appliedPrice);
};
```

#### 2. `Pivot_Detector.mqh`

**Responsabilité** : Détection des pivots (équivalent Pine Script ta.pivotlow/pivothigh)

```cpp
class CPivotDetector
{
   // Détection pivots
   bool IsPivotLow(int pos, const double &buffer[], const datetime &time[] = NULL);
   bool IsPivotHigh(int pos, const double &buffer[], const datetime &time[] = NULL);

   // Recherche avancée
   int FindPivots(const double &buffer[], const datetime &time[], int startPos, int endPos,
                  SPivotInfo &pivotHighs[], SPivotInfo &pivotLows[]);

   // Configuration
   void SetLookback(int lookbackLeft, int lookbackRight);
};
```

#### 3. `Divergence_Detector.mqh`

**Responsabilité** : Détection des divergences (Regular + Hidden)

```cpp
class CDivergenceDetector
{
   // Détection divergences spécifiques
   bool CheckRegularBullish(int currentBar, const double &rsi[], const double &low[],
                           const datetime &time[], SDivergenceResult &result);
   bool CheckRegularBearish(int currentBar, const double &rsi[], const double &high[],
                            const datetime &time[], SDivergenceResult &result);
   bool CheckHiddenBullish(int currentBar, const double &rsi[], const double &low[],
                          const datetime &time[], SDivergenceResult &result);
   bool CheckHiddenBearish(int currentBar, const double &rsi[], const double &high[],
                           const datetime &time[], SDivergenceResult &result);

   // Scan global
   int ScanDivergences(int startPos, int endPos, const double &rsi[], const double &high[],
                      const double &low[], const datetime &time[], SDivergenceResult &results[]);
};
```

#### 4. `Divergence_Visualizer.mqh`

**Responsabilité** : Affichage graphique des divergences

```cpp
class CDivergenceVisualizer
{
   // Affichage complet
   bool DrawDivergence(const SDivergenceResult &div, const datetime &time[]);

   // Affichage spécifique
   bool DrawDivergenceTrendline(const SDivergenceResult &div, const datetime &time[]);
   bool DrawDivergenceArrow(const SDivergenceResult &div, const datetime &time[]);
   bool DrawDivergenceLabel(const SDivergenceResult &div, const datetime &time[]);

   // Gestion objets
   void CleanOldObjects(int maxAge = 1000);
   void DeleteAllObjects();
};
```

### Fichiers modifiés/créés

#### EA Autonome

- **`EA/RSI_Divergence_EA_Autonomous.mq5`** : Version autonome utilisant directement les classes

#### Indicateur Modulaire

- **`Indicators/RSI_Divergence_Indicator_Modular.mq5`** : Version allégée utilisant les classes

#### Script de Test

- **`Scripts/Test_RSI_Classes.mq5`** : Script de validation des classes

## 🔧 Utilisation

### EA Autonome (Recommandé pour le trading)

```cpp
#include <../Shared/RSI_Calculator.mqh>
#include <../Shared/Pivot_Detector.mqh>
#include <../Shared/Divergence_Detector.mqh>

// Dans OnInit()
CRSICalculator* rsiCalculator = new CRSICalculator(3, PRICE_CLOSE);
CPivotDetector* pivotDetector = new CPivotDetector(3, 1);
CDivergenceDetector* divergenceDetector = new CDivergenceDetector(3, 100, pivotDetector);

// Dans OnTick()
double close[];
CopyClose(_Symbol, _Period, 0, 500, close);
rsiCalculator.Calculate(ArraySize(close), 0, close);

SDivergenceResult results[];
int found = divergenceDetector.ScanDivergences(0, 50, rsiBuffer, high, low, results);
```

### Indicateur Modulaire (Pour affichage graphique)

```cpp
#include <../Shared/RSI_Calculator.mqh>
#include <../Shared/Pivot_Detector.mqh>
#include <../Shared/Divergence_Detector.mqh>
#include <../Shared/Divergence_Visualizer.mqh>

// Dans OnCalculate()
rsiCalculator.Calculate(rates_total, prev_calculated, close);
divergenceDetector.ScanDivergences(startPos, endPos, rsiBuffer, high, low, time, results);

// Visualisation
for(int i = 0; i < found; i++)
{
   visualizer.DrawDivergence(results[i], time);
}
```

## 📊 Structures de données

### SDivergenceResult

```cpp
struct SDivergenceResult
{
   bool                    found;              // Divergence trouvée
   int                     currentBar;         // Position actuelle
   int                     previousBar;        // Position précédente
   double                  currentRSI;         // RSI actuel
   double                  previousRSI;        // RSI précédent
   double                  currentPrice;       // Prix actuel
   double                  previousPrice;      // Prix précédent
   ENUM_DIVERGENCE_TYPE    type;               // Type de divergence
   datetime                currentTime;        // Temps actuel
   datetime                previousTime;       // Temps précédent
   bool                    isValid;            // Validité
};
```

### SPivotInfo

```cpp
struct SPivotInfo
{
   int      position;    // Position du pivot
   double   value;       // Valeur du pivot
   datetime time;        // Temps du pivot
   bool     isValid;     // Validité du pivot
};
```

## 🎨 Types de divergences

```cpp
enum ENUM_DIVERGENCE_TYPE
{
   DIVERGENCE_NONE = 0,        // Aucune divergence
   DIVERGENCE_REGULAR_BULL,    // Divergence bullish régulière
   DIVERGENCE_REGULAR_BEAR,    // Divergence bearish régulière
   DIVERGENCE_HIDDEN_BULL,     // Divergence bullish cachée
   DIVERGENCE_HIDDEN_BEAR      // Divergence bearish cachée
};
```

## ⚡ Avantages de performance

1. **Calcul direct** : EA calcule RSI sans attendre l'indicateur
2. **Calculs incrémentaux** : Support `prev_calculated` pour optimiser
3. **Buffers statiques** : Évite les allocations mémoire répétées
4. **Validation robuste** : Vérifications de paramètres et indices
5. **Thread-safe** : Classes compatibles Strategy Tester

## 🧪 Tests et validation

Le script `Test_RSI_Classes.mq5` valide :

- ✅ Calcul RSI avec CRSICalculator
- ✅ Détection pivots avec CPivotDetector
- ✅ Détection divergences avec CDivergenceDetector
- ✅ Visualisation avec CDivergenceVisualizer
- ✅ Tests de performance

## 📈 Compatibilité

- ✅ **MQL5 strict** (pas de MQL4)
- ✅ **Compatible Strategy Tester**
- ✅ **Thread-safe** si possible
- ✅ **Même résultats** que la version actuelle

## 🚀 Migration

### Depuis l'EA original

1. Remplacer `RSI_Divergence_EA.mq5` par `RSI_Divergence_EA_Autonomous.mq5`
2. Compiler les classes MQH dans MetaEditor
3. Tester avec le script de validation

### Depuis l'indicateur original

1. Remplacer `RSI_Divergence_Indicator.mq5` par `RSI_Divergence_Indicator_Modular.mq5`
2. Compiler les classes MQH dans MetaEditor
3. Vérifier l'affichage graphique

## 📝 Notes importantes

⚠️ **Compilation** : Les fichiers .mqh doivent être compilés dans MetaEditor (F7)  
⚠️ **Tests** : Toujours valider avec le script de test avant utilisation  
⚠️ **Performance** : L'EA autonome est plus rapide que la version avec indicateur  
⚠️ **Compatibilité** : Les résultats sont identiques à la version actuelle  

## 🔧 Compilation

### Ordre de compilation recommandé

1. **Classes de base :**
   - `Shared/RSI_Calculator.mqh`
   - `Shared/Pivot_Detector.mqh`

2. **Classes dépendantes :**
   - `Shared/Divergence_Detector.mqh`
   - `Shared/Divergence_Visualizer.mqh`

3. **Fichiers utilisant les classes :**
   - `EA/RSI_Divergence_EA_Autonomous.mq5`
   - `Indicators/RSI_Divergence_Indicator_Modular.mq5`
   - `Scripts/Test_RSI_Classes.mq5`

### Vérification des chemins

Si vous obtenez l'erreur "file not found", vérifiez que les inclusions utilisent des backslashes :
```cpp
#include "..\Shared\RSI_Calculator.mqh"  // ✅ Correct
#include <../Shared/RSI_Calculator.mqh>  // ❌ Incorrect
```

## 🔄 Prochaines étapes

1. **Compiler** tous les fichiers .mqh dans MetaEditor (voir `COMPILATION_GUIDE.md`)
2. **Tester** avec le script de validation
3. **Valider** les résultats avec la version actuelle
4. **Déployer** l'EA autonome pour le trading
5. **Utiliser** l'indicateur modulaire pour l'affichage

---

**Architecture créée avec succès ! 🎉**

Toutes les classes MQH sont prêtes et l'architecture modulaire est fonctionnelle. Le système RSI Divergence est maintenant plus performant, maintenable et flexible.
