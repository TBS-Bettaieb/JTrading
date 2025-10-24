# 🚀 Scripts de Déploiement - RSI Divergence Trading System

## 📋 Vue d'ensemble

Ce dossier contient des scripts PowerShell et Batch pour automatiser le déploiement des indicateurs, EAs et dépendances vers le dossier parent MQL5.

## 📁 Scripts disponibles

### 🔧 Scripts individuels

#### 1. **Deploy_Indicator.ps1** / **Deploy_Indicator.bat**

Déploie un indicateur spécifique et ses dépendances.

**Usage PowerShell:**

```powershell
.\Deploy_Indicator.ps1 -IndicatorName "RSI_Divergence_Indicator_Modular"
```

**Usage Batch:**

```batch
Deploy_Indicator.bat "RSI_Divergence_Indicator_Modular"
```

#### 2. **Deploy_EA.ps1** / **Deploy_EA.bat**

Déploie un EA spécifique et ses dépendances.

**Usage PowerShell:**

```powershell
.\Deploy_EA.ps1 -EAName "RSI_Divergence_EA_Autonomous"
```

**Usage Batch:**

```batch
Deploy_EA.bat "RSI_Divergence_EA_Autonomous"
```

### 🌐 Scripts de déploiement complet

#### 3. **Deploy_All.ps1** / **Deploy_All.bat**

Déploie tous les fichiers du système (indicateurs, EAs, dépendances).

**Usage PowerShell:**

```powershell
.\Deploy_All.ps1
```

**Usage Batch:**

```batch
Deploy_All.bat
```

## 📂 Structure de déploiement

```
MQL5/
├── Shared/                    ← Dépendances partagées (.mqh)
│   ├── RSI_Calculator.mqh
│   ├── Pivot_Detector.mqh
│   ├── Divergence_Detector.mqh
│   └── Divergence_Visualizer.mqh
├── Indicators/                ← Indicateurs (.mq5)
│   ├── RSI_Divergence_Indicator_Modular.mq5
│   └── RSI_Divergence_Indicator.mq5
└── Experts/                   ← EAs (.mq5)
    ├── RSI_Divergence_EA_Autonomous.mq5
    └── RSI_Divergence_EA.mq5
```

## 🎯 Cas d'usage

### Déploiement d'un indicateur spécifique

```powershell
# Déployer seulement l'indicateur modulaire
.\Deploy_Indicator.ps1 -IndicatorName "RSI_Divergence_Indicator_Modular"
```

### Déploiement d'un EA spécifique

```powershell
# Déployer seulement l'EA autonome
.\Deploy_EA.ps1 -EAName "RSI_Divergence_EA_Autonomous"
```

### Déploiement complet du système

```powershell
# Déployer tous les fichiers
.\Deploy_All.ps1
```

## ⚙️ Options avancées

### PowerShell uniquement

#### Forcer le déploiement

```powershell
.\Deploy_Indicator.ps1 -IndicatorName "RSI_Divergence_Indicator_Modular" -Force
```

#### Déployer sans dépendances

```powershell
.\Deploy_Indicator.ps1 -IndicatorName "RSI_Divergence_Indicator_Modular" -IncludeDependencies:$false
```

## 🔍 Vérification du déploiement

Après le déploiement, vérifiez que les fichiers sont bien copiés :

1. **Dépendances partagées** : `MQL5/Shared/`
2. **Indicateurs** : `MQL5/Indicators/`
3. **EAs** : `MQL5/Experts/`

## 🚨 Résolution de problèmes

### Erreur : "Le fichier n'existe pas"

- Vérifiez que le nom du fichier est correct
- Vérifiez que le fichier existe dans le dossier source

### Erreur : "Accès refusé"

- Exécutez le script en tant qu'administrateur
- Vérifiez que MetaTrader 5 n'est pas en cours d'exécution

### Erreur : "Dossier de destination introuvable"

- Le script créera automatiquement les dossiers nécessaires
- Vérifiez les permissions d'écriture

## 📝 Notes importantes

- Les scripts créent automatiquement les dossiers de destination s'ils n'existent pas
- Les fichiers existants sont remplacés par défaut
- Les dépendances partagées sont copiées dans `MQL5/Shared/`
- Les chemins d'inclusion dans les fichiers .mq5 doivent utiliser `<Shared\...>` pour les dépendances

## 🎉 Exemple de déploiement complet

```powershell
# 1. Déployer tous les fichiers
.\Deploy_All.ps1

# 2. Vérifier le déploiement
Get-ChildItem "..\..\MQL5\Shared\*.mqh"
Get-ChildItem "..\..\MQL5\Indicators\*.mq5"
Get-ChildItem "..\..\MQL5\Experts\*.mq5"
```

---

**✅ Avec ces scripts, le déploiement de votre système RSI Divergence est automatisé et simplifié !**
