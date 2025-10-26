# 📦 Guide d'Installation - EA JTFreeCandle_v2

## 📋 Table des Matières

1. [Prérequis Système](#prérequis-système)
2. [Installation Windows](#installation-windows)
3. [Installation Linux](#installation-linux)
4. [Installation macOS](#installation-macos)
5. [Vérification de l'Installation](#vérification-de-linstallation)
6. [Configuration Post-Installation](#configuration-post-installation)
7. [Troubleshooting](#troubleshooting)

---

## 🖥️ Prérequis Système

### Configuration Minimale

- **OS**: Windows 10/11, Linux (Ubuntu 20.04+, Fedora 35+), macOS 10.15+
- **RAM**: 4 GB minimum (8 GB recommandé)
- **Disque**: 2 GB d'espace libre
- **Processeur**: Intel Core i3 ou équivalent
- **Connexion Internet**: Requise pour le téléchargement

### Logiciels Requis

#### ✅ **Python 3.8 ou supérieur**
- **Windows**: [python.org/downloads](https://www.python.org/downloads/)
- **Linux**: `sudo apt-get install python3 python3-pip` (Ubuntu/Debian)
- **macOS**: `brew install python3`

**Vérification**:
```bash
python --version  # ou python3 --version
```

#### ✅ **MetaTrader 5**
- **Windows**: [metatrader5.com/en/download](https://www.metatrader5.com/en/download)
- **Linux/macOS**: Requiert Wine ou VM Windows

**Vérification**:
- Ouvrez MetaTrader 5
- Allez dans `Aide > À propos`
- Vérifiez la version

#### ✅ **pip (Gestionnaire de packages Python)**
Généralement installé avec Python. Si absent:
```bash
python -m ensurepip --upgrade
```

---

## 🪟 Installation Windows

### Méthode 1: Installation Automatique (Recommandée)

1. **Télécharger le projet**
   ```cmd
   git clone <repository_url>
   cd JTrading/Pyth
   ```

2. **Lancer l'installateur**
   Double-cliquez sur `tools/install_windows.bat` ou exécutez:
   ```cmd
   tools\install_windows.bat
   ```

3. **Suivre les instructions**
   L'installateur va:
   - ✅ Vérifier Python et pip
   - ✅ Installer les dépendances (`requirements.txt`)
   - ✅ Détecter MetaTrader 5
   - ✅ Créer les dossiers nécessaires
   - ✅ Vérifier l'installation

### Méthode 2: Installation Manuelle

1. **Installer Python 3.8+**
   - Téléchargez depuis [python.org](https://www.python.org/downloads/)
   - **Important**: Cochez "Add Python to PATH" pendant l'installation

2. **Ouvrir PowerShell/CMD dans le dossier Pyth**
   ```cmd
   cd chemin\vers\JTrading\Pyth
   ```

3. **Créer un environnement virtuel (optionnel mais recommandé)**
   ```cmd
   python -m venv venv
   venv\Scripts\activate
   ```

4. **Installer les dépendances**
   ```cmd
   pip install -r requirements.txt
   ```

5. **Créer les dossiers nécessaires**
   ```cmd
   mkdir EA_Workflow\configs EA_Workflow\set_files EA_Workflow\reports EA_Workflow\results MT5_Sets
   ```

6. **Vérifier l'installation**
   ```cmd
   python tools\check_dependencies.py
   ```

### Configuration MetaTrader 5 (Windows)

1. **Installer MT5**
   - Téléchargez depuis [metatrader5.com](https://www.metatrader5.com/)
   - Installez dans `C:\Program Files\MetaTrader 5\`

2. **Activer l'API**
   - Ouvrez MT5
   - `Outils > Options > Expert Advisors`
   - Cochez:
     - ✅ `Autoriser l'importation de DLL`
     - ✅ `Autoriser le trading automatique`
     - ✅ `Autoriser les imports WebRequest`

3. **Connecter à un compte**
   - Compte démo: `Fichier > Ouvrir un compte > Compte démo`
   - Compte réel: Suivez les instructions de votre broker

---

## 🐧 Installation Linux

### Ubuntu / Debian

1. **Installer Python et pip**
   ```bash
   sudo apt-get update
   sudo apt-get install python3 python3-pip python3-venv git
   ```

2. **Cloner le projet**
   ```bash
   git clone <repository_url>
   cd JTrading/Pyth
   ```

3. **Lancer l'installateur**
   ```bash
   chmod +x tools/install_linux.sh
   ./tools/install_linux.sh
   ```

### Installation de MetaTrader 5 sur Linux

MT5 nécessite Wine pour fonctionner sur Linux.

1. **Installer Wine**
   ```bash
   # Ubuntu/Debian
   sudo dpkg --add-architecture i386
   sudo apt-get update
   sudo apt-get install wine64 wine32
   
   # Fedora
   sudo dnf install wine
   ```

2. **Télécharger MT5**
   ```bash
   wget https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe
   ```

3. **Installer MT5 via Wine**
   ```bash
   wine mt5setup.exe
   ```

4. **Lancer MT5**
   ```bash
   wine ~/.wine/drive_c/Program\ Files/MetaTrader\ 5/terminal64.exe
   ```

### Fedora / RHEL

```bash
sudo dnf install python3 python3-pip git
./tools/install_linux.sh
```

---

## 🍎 Installation macOS

### Prérequis

1. **Installer Homebrew** (si pas déjà installé)
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. **Installer Python**
   ```bash
   brew install python3
   ```

3. **Cloner le projet**
   ```bash
   git clone <repository_url>
   cd JTrading/Pyth
   ```

4. **Lancer l'installateur**
   ```bash
   chmod +x tools/install_linux.sh
   ./tools/install_linux.sh
   ```

### MetaTrader 5 sur macOS

MT5 n'est pas natif sur macOS. Voici les options:

#### Option 1: Wine (Recommandé)

```bash
brew install --cask wine-stable
```

Puis installez MT5 via Wine:
```bash
wine mt5setup.exe
```

#### Option 2: PlayOnMac

1. Téléchargez [PlayOnMac](https://www.playonmac.com/)
2. Installez MT5 via PlayOnMac

#### Option 3: Machine Virtuelle

1. Installez [VirtualBox](https://www.virtualbox.org/) ou [Parallels](https://www.parallels.com/)
2. Créez une VM Windows
3. Installez MT5 dans la VM

---

## ✅ Vérification de l'Installation

### Script de Vérification Automatique

```bash
python tools/check_dependencies.py
```

**Sortie attendue:**
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

[4/8] Vérification des packages optionnels...
...

======================================================================
  RÉSUMÉ
======================================================================

✅ Toutes les dépendances requises sont installées!
```

### Tests Manuels

#### 1. Test Python
```python
python -c "import pandas, numpy, matplotlib, seaborn, MetaTrader5; print('✅ OK')"
```

#### 2. Test MT5
```python
python -c "import MetaTrader5 as mt5; print('✅ OK' if mt5.initialize() else '❌ Erreur')"
```

#### 3. Test des Scripts
```bash
python ea_workflow.py --help  # Devrait afficher le menu
```

---

## ⚙️ Configuration Post-Installation

### 1. Configuration MT5

#### Activer l'API Python
1. Ouvrez MT5
2. `Outils > Options > Expert Advisors`
3. Activez:
   - ✅ Autoriser l'importation de DLL
   - ✅ Autoriser le trading automatique
   - ✅ Autoriser les imports WebRequest

#### Configurer le Chemin MT5 (si non-standard)
Éditez `ea_launcher.py`:
```python
launcher = MT5EALauncher(mt5_path="C:/Custom/Path/MetaTrader 5/terminal64.exe")
```

### 2. Structure des Dossiers

Vérifiez que ces dossiers existent:
```
Pyth/
├── EA_Workflow/
│   ├── configs/      # Configurations générées
│   ├── set_files/    # Fichiers .set pour MT5
│   ├── reports/      # Rapports HTML
│   └── results/      # Résultats d'analyse
├── MT5_Sets/         # Fichiers .set supplémentaires
└── data_cache/       # Cache des données historiques
```

### 3. Premier Test

Lancez le workflow pour tester:
```bash
python ea_workflow.py
```

Choisissez l'option 1 (Workflow complet automatique) pour générer des configurations de test.

---

## 🔧 Troubleshooting

### Problème: Python n'est pas reconnu

**Symptôme**: `'python' is not recognized as an internal or external command`

**Solution**:
1. Ajoutez Python au PATH:
   - Windows: `Panneau de configuration > Système > Variables d'environnement`
   - Ajoutez `C:\Python310` et `C:\Python310\Scripts` au PATH

2. Ou utilisez le Python Launcher:
   ```cmd
   py -3 ea_workflow.py
   ```

### Problème: pip install échoue

**Symptôme**: `ERROR: Could not install packages`

**Solutions**:
1. **Mise à jour de pip**:
   ```bash
   python -m pip install --upgrade pip
   ```

2. **Installation avec droits admin** (Windows):
   ```cmd
   # Ouvrez CMD en tant qu'administrateur
   pip install -r requirements.txt
   ```

3. **Installation utilisateur**:
   ```bash
   pip install --user -r requirements.txt
   ```

### Problème: MT5 ne se connecte pas

**Symptôme**: `MT5 non connecté` dans check_dependencies.py

**Solutions**:
1. **Vérifiez que MT5 est ouvert** et connecté à un compte
2. **Vérifiez les permissions** dans MT5:
   - `Outils > Options > Expert Advisors`
   - Activez toutes les options
3. **Redémarrez MT5** et réessayez

### Problème: MetaTrader5 package non trouvé

**Symptôme**: `ModuleNotFoundError: No module named 'MetaTrader5'`

**Solutions**:
1. **Installation directe**:
   ```bash
   pip install MetaTrader5
   ```

2. **Vérifiez le bon environnement Python**:
   ```bash
   pip list | grep MetaTrader5
   ```

### Problème: Erreurs sur Linux/macOS

**Symptôme**: Scripts ne fonctionnent pas correctement

**Solutions**:
1. **Rendre les scripts exécutables**:
   ```bash
   chmod +x tools/install_linux.sh
   chmod +x tools/check_dependencies.py
   ```

2. **Utiliser python3 explicitement**:
   ```bash
   python3 ea_workflow.py
   ```

3. **Installer Wine correctement** (pour MT5):
   ```bash
   # Ubuntu
   sudo dpkg --add-architecture i386
   sudo apt-get update
   sudo apt-get install wine64 wine32 winetricks
   ```

### Problème: Modules manquants après installation

**Symptôme**: `ImportError` même après `pip install`

**Solutions**:
1. **Vérifiez quel Python est utilisé**:
   ```bash
   which python
   python --version
   ```

2. **Installez dans le bon Python**:
   ```bash
   python3 -m pip install -r requirements.txt
   ```

3. **Utilisez un environnement virtuel**:
   ```bash
   python -m venv venv
   source venv/bin/activate  # Linux/macOS
   venv\Scripts\activate     # Windows
   pip install -r requirements.txt
   ```

### Problème: Permission denied (Linux/macOS)

**Symptôme**: `PermissionError: [Errno 13] Permission denied`

**Solutions**:
1. **Installation utilisateur**:
   ```bash
   pip install --user -r requirements.txt
   ```

2. **Utiliser sudo** (pas recommandé):
   ```bash
   sudo pip3 install -r requirements.txt
   ```

3. **Environnement virtuel** (recommandé):
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```

---

## 📞 Support

### Documentation
- [QUICKSTART.md](QUICKSTART.md) - Guide de démarrage rapide
- [USAGE_LAUNCHER.md](USAGE_LAUNCHER.md) - Documentation du launcher
- [USAGE_WORKFLOW.md](USAGE_WORKFLOW.md) - Documentation du workflow
- [USAGE_OPTIMIZER.md](USAGE_OPTIMIZER.md) - Documentation de l'optimiseur

### Logs
Les logs sont sauvegardés dans:
- `ea_launcher.log` - Logs du launcher
- `EA_Workflow/` - Logs du workflow

### Commandes Utiles

```bash
# Vérifier l'installation
python tools/check_dependencies.py

# Voir la version de Python
python --version

# Lister les packages installés
pip list

# Mettre à jour pip
python -m pip install --upgrade pip

# Réinstaller toutes les dépendances
pip install --force-reinstall -r requirements.txt
```

---

**Version**: 1.0  
**Date**: Octobre 2025  
**Status**: ✅ **PRODUCTION READY**

