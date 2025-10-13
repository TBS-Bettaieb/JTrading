# 🛠️ Tools - EA JTFreeCandle_v2

## 📁 Contenu du Dossier

Ce dossier contient tous les outils nécessaires pour installer, configurer et utiliser l'EA JTFreeCandle_v2.

```
tools/
├── install_windows.bat       # Installation automatique Windows
├── install_linux.sh           # Installation Linux/macOS
├── check_dependencies.py      # Vérification des dépendances
├── docs/                      # Documentation complète
│   ├── INSTALLATION.md        # Guide d'installation détaillé
│   ├── QUICKSTART.md          # Guide de démarrage rapide
│   ├── USAGE_LAUNCHER.md      # Documentation ea_launcher.py
│   ├── USAGE_WORKFLOW.md      # Documentation ea_workflow.py
│   └── USAGE_OPTIMIZER.md     # Documentation ea_optimizer.py
└── README.md                  # Ce fichier
```

---

## 🚀 Installation Rapide

### Windows

```cmd
tools\install_windows.bat
```

### Linux/macOS

```bash
chmod +x tools/install_linux.sh
./tools/install_linux.sh
```

### Vérification

```bash
python tools/check_dependencies.py
```

---

## 📚 Documentation

### 🎯 Débutant ? Commencez ici !

1. **[QUICKSTART.md](docs/QUICKSTART.md)** - Guide de démarrage rapide (5 minutes)
   - Installation en 3 commandes
   - Premier workflow
   - Exemples simples

### 📖 Documentation Complète

2. **[INSTALLATION.md](docs/INSTALLATION.md)** - Guide d'installation détaillé
   - Prérequis système
   - Installation Windows/Linux/macOS
   - Configuration MetaTrader 5
   - Troubleshooting complet

### 🔧 Guides d'Utilisation

3. **[USAGE_LAUNCHER.md](docs/USAGE_LAUNCHER.md)** - Documentation `ea_launcher.py`
   - Création de configurations
   - Gestion multi-configs
   - Monitoring en temps réel
   - Analyse des résultats

4. **[USAGE_WORKFLOW.md](docs/USAGE_WORKFLOW.md)** - Documentation `ea_workflow.py`
   - Workflow automatisé complet
   - Génération de configurations
   - Création de fichiers .set
   - Rapports HTML

5. **[USAGE_OPTIMIZER.md](docs/USAGE_OPTIMIZER.md)** - Documentation `ea_optimizer.py`
   - Optimisation de paramètres
   - Grid Search & Random Search
   - Analyse de performance
   - Métriques avancées

---

## 🎯 Cas d'Usage

### Je veux...

#### 🆕 **Installer le système**
→ [INSTALLATION.md](docs/INSTALLATION.md)  
→ Lancez `install_windows.bat` ou `install_linux.sh`

#### ⚡ **Commencer rapidement**
→ [QUICKSTART.md](docs/QUICKSTART.md)  
→ 5 minutes pour votre premier workflow

#### 🔧 **Créer des configurations personnalisées**
→ [USAGE_LAUNCHER.md](docs/USAGE_LAUNCHER.md)  
→ Section "Création de Configuration"

#### 🔄 **Automatiser tout le processus**
→ [USAGE_WORKFLOW.md](docs/USAGE_WORKFLOW.md)  
→ Workflow complet en un clic

#### 📊 **Analyser mes résultats de trading**
→ [USAGE_OPTIMIZER.md](docs/USAGE_OPTIMIZER.md)  
→ Classe `EAAnalyzer`

#### ⚙️ **Optimiser mes paramètres**
→ [USAGE_OPTIMIZER.md](docs/USAGE_OPTIMIZER.md)  
→ Grid Search & Random Search

---

## 🛠️ Scripts d'Installation

### `install_windows.bat`

**Fonctionnalités**:
- ✅ Vérification Python et pip
- ✅ Installation automatique des dépendances
- ✅ Détection MetaTrader 5
- ✅ Création des dossiers de travail
- ✅ Vérification finale

**Utilisation**:
```cmd
cd Pyth
tools\install_windows.bat
```

### `install_linux.sh`

**Fonctionnalités**:
- ✅ Support Linux et macOS
- ✅ Détection automatique Python3
- ✅ Installation avec pip3
- ✅ Configuration Wine (pour MT5)
- ✅ Permissions exécutables

**Utilisation**:
```bash
cd Pyth
chmod +x tools/install_linux.sh
./tools/install_linux.sh
```

### `check_dependencies.py`

**Fonctionnalités**:
- ✅ Vérification Python 3.8+
- ✅ Vérification packages requis
- ✅ Vérification MetaTrader5
- ✅ Test de connexion MT5
- ✅ Vérification structure projet
- ✅ Rapport détaillé

**Utilisation**:
```bash
python tools/check_dependencies.py
```

**Sortie**:
```
======================================================================
  Vérification des Dépendances - EA JTFreeCandle_v2
======================================================================

[1/8] Vérification de la version Python...
✅ Python 3.10.0 - OK

[2/8] Vérification des packages Python essentiels...
✅ pandas (1.5.3) - OK
✅ numpy (1.24.2) - OK
✅ matplotlib (3.7.1) - OK
✅ seaborn (0.12.2) - OK

[3/8] Vérification du package MetaTrader5...
✅ MetaTrader5 (5.0.40) - OK

...

======================================================================
  RÉSUMÉ
======================================================================

✅ Toutes les dépendances requises sont installées!
```

---

## 📖 Structure de la Documentation

### Format Markdown

Tous les documents sont en Markdown pour:
- ✅ Lecture facile sur GitHub
- ✅ Conversion HTML/PDF possible
- ✅ Intégration dans IDEs
- ✅ Recherche de texte simple

### Sections Standardisées

Chaque document contient:
- 📋 **Table des Matières** - Navigation rapide
- 🎯 **Vue d'Ensemble** - Introduction
- 💡 **Exemples** - Code pratique
- 🔧 **Troubleshooting** - Solutions aux problèmes
- 📚 **API Reference** - Référence technique

---

## 🆘 Support

### 📍 Problème d'Installation ?
→ [INSTALLATION.md](docs/INSTALLATION.md) section "Troubleshooting"

### 📍 Questions sur l'Utilisation ?
→ Consultez le guide correspondant:
- [USAGE_LAUNCHER.md](docs/USAGE_LAUNCHER.md)
- [USAGE_WORKFLOW.md](docs/USAGE_WORKFLOW.md)
- [USAGE_OPTIMIZER.md](docs/USAGE_OPTIMIZER.md)

### 📍 Premiers Pas ?
→ [QUICKSTART.md](docs/QUICKSTART.md)

### 📍 Vérification Système ?
```bash
python tools/check_dependencies.py
```

---

## 🎓 Parcours d'Apprentissage

### Niveau 1: Débutant (1 heure)
1. ✅ Lire [QUICKSTART.md](docs/QUICKSTART.md)
2. ✅ Installer avec les scripts automatiques
3. ✅ Lancer premier workflow
4. ✅ Tester les fichiers .set dans MT5

### Niveau 2: Intermédiaire (3 heures)
1. ✅ Lire [USAGE_WORKFLOW.md](docs/USAGE_WORKFLOW.md)
2. ✅ Générer différents types de configs
3. ✅ Analyser les résultats
4. ✅ Comprendre les métriques

### Niveau 3: Avancé (1 jour)
1. ✅ Lire [USAGE_LAUNCHER.md](docs/USAGE_LAUNCHER.md)
2. ✅ Lire [USAGE_OPTIMIZER.md](docs/USAGE_OPTIMIZER.md)
3. ✅ Créer des configurations personnalisées
4. ✅ Optimiser avec Grid Search
5. ✅ Analyser en profondeur

### Niveau 4: Expert (1 semaine)
1. ✅ Modifier les configurations smart
2. ✅ Personnaliser l'espace de paramètres
3. ✅ Créer des rapports personnalisés
4. ✅ Intégrer dans votre workflow

---

## 📊 Diagramme du Workflow

```
┌─────────────────────────────────────────────────────────────┐
│                   INSTALLATION                              │
│  install_windows.bat / install_linux.sh                     │
│  ↓                                                           │
│  check_dependencies.py                                      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                GÉNÉRATION DE CONFIGURATIONS                 │
│  ea_optimizer.py  →  Smart/Grid/Random Configs              │
│  ea_workflow.py   →  Workflow Automatisé                    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                FICHIERS .SET POUR MT5                       │
│  EA_Workflow/set_files/                                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    TESTS DANS MT5                           │
│  Strategy Tester  →  Backtests  →  CSV Results             │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   ANALYSE DES RÉSULTATS                     │
│  ea_optimizer.py (EAAnalyzer)                               │
│  ↓                                                           │
│  • Métriques de performance                                 │
│  • Graphiques & visualisations                              │
│  • Rapports HTML                                            │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔗 Liens Rapides

| Document | Description | Temps de Lecture |
|----------|-------------|------------------|
| [QUICKSTART.md](docs/QUICKSTART.md) | Démarrage en 5 min | 5 min |
| [INSTALLATION.md](docs/INSTALLATION.md) | Guide complet | 15 min |
| [USAGE_LAUNCHER.md](docs/USAGE_LAUNCHER.md) | ea_launcher.py | 20 min |
| [USAGE_WORKFLOW.md](docs/USAGE_WORKFLOW.md) | ea_workflow.py | 15 min |
| [USAGE_OPTIMIZER.md](docs/USAGE_OPTIMIZER.md) | ea_optimizer.py | 20 min |

---

## 📝 Licence

Documentation © 2025 - EA JTFreeCandle_v2

---

## 🎯 Prêt à Commencer ?

```bash
# 1. Installation
tools/install_windows.bat  # ou ./tools/install_linux.sh

# 2. Vérification
python tools/check_dependencies.py

# 3. Premier workflow
python ea_workflow.py

# 4. C'est tout ! 🚀
```

**Besoin d'aide ?** Consultez [QUICKSTART.md](docs/QUICKSTART.md) ou [INSTALLATION.md](docs/INSTALLATION.md)

---

**Version**: 1.0  
**Date**: Octobre 2025  
**Status**: ✅ **PRODUCTION READY**

