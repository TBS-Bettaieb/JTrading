#!/bin/bash
# ============================================================================
# Installation automatique EA JTFreeCandle_v2 - Linux/Mac
# ============================================================================

set -e  # Arrêter en cas d'erreur

echo ""
echo "========================================================================"
echo "  EA JTFreeCandle_v2 - Installation Automatique pour Linux/Mac"
echo "========================================================================"
echo ""

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERREUR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[AVERTISSEMENT]${NC} $1"
}

print_info() {
    echo -e "[INFO] $1"
}

# Étape 1: Vérification Python
echo "[1/6] Vérification de Python..."
if command -v python3 &> /dev/null; then
    PYTHON_CMD=python3
    print_success "Python 3 trouvé: $(python3 --version)"
elif command -v python &> /dev/null; then
    PYTHON_VERSION=$(python --version 2>&1)
    if [[ $PYTHON_VERSION == *"Python 3"* ]]; then
        PYTHON_CMD=python
        print_success "Python trouvé: $PYTHON_VERSION"
    else
        print_error "Python 3 est requis. Version trouvée: $PYTHON_VERSION"
        exit 1
    fi
else
    print_error "Python n'est pas installé"
    echo ""
    echo "Installation de Python:"
    echo "  Ubuntu/Debian: sudo apt-get install python3 python3-pip"
    echo "  Fedora/RHEL:   sudo dnf install python3 python3-pip"
    echo "  macOS:         brew install python3"
    exit 1
fi
echo ""

# Étape 2: Vérification pip
echo "[2/6] Vérification de pip..."
if command -v pip3 &> /dev/null; then
    PIP_CMD=pip3
    print_success "pip3 trouvé"
elif command -v pip &> /dev/null; then
    PIP_CMD=pip
    print_success "pip trouvé"
else
    print_error "pip n'est pas disponible"
    print_info "Installation de pip..."
    $PYTHON_CMD -m ensurepip --upgrade
    PIP_CMD="$PYTHON_CMD -m pip"
fi
echo ""

# Étape 3: Installation des dépendances
echo "[3/6] Installation des dépendances Python..."
echo ""

if [ -f "requirements.txt" ]; then
    print_info "Installation depuis requirements.txt..."
    $PIP_CMD install -r requirements.txt
    if [ $? -ne 0 ]; then
        print_error "Échec de l'installation des dépendances"
        exit 1
    fi
else
    print_warning "requirements.txt non trouvé"
    print_info "Installation des packages essentiels..."
    $PIP_CMD install pandas numpy matplotlib seaborn MetaTrader5
fi

print_success "Dépendances installées"
echo ""

# Étape 4: Vérification MetaTrader 5
echo "[4/6] Vérification de MetaTrader 5..."

MT5_FOUND=0

# Sur Linux, MT5 nécessite Wine
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if command -v wine &> /dev/null; then
        print_success "Wine est installé (requis pour MT5 sur Linux)"
        MT5_FOUND=1
    else
        print_warning "Wine n'est pas installé"
        echo ""
        echo "Pour utiliser MT5 sur Linux, installez Wine:"
        echo "  Ubuntu/Debian: sudo apt-get install wine"
        echo "  Fedora/RHEL:   sudo dnf install wine"
        echo ""
    fi
fi

# Sur macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    print_warning "MT5 nécessite Wine ou PlayOnMac sur macOS"
    echo ""
    echo "Options pour MT5 sur macOS:"
    echo "  1. Installer Wine: brew install --cask wine-stable"
    echo "  2. Utiliser PlayOnMac: https://www.playonmac.com/"
    echo "  3. Utiliser une VM Windows"
    echo ""
fi

echo ""

# Étape 5: Création des dossiers nécessaires
echo "[5/6] Création des dossiers de travail..."

mkdir -p EA_Workflow/configs
mkdir -p EA_Workflow/set_files
mkdir -p EA_Workflow/reports
mkdir -p EA_Workflow/results
mkdir -p MT5_Sets

print_success "Dossiers créés:"
echo "  - EA_Workflow/"
echo "  - EA_Workflow/configs/"
echo "  - EA_Workflow/set_files/"
echo "  - EA_Workflow/reports/"
echo "  - EA_Workflow/results/"
echo "  - MT5_Sets/"
echo ""

# Étape 6: Rendre les scripts exécutables
echo "[6/6] Configuration des permissions..."
chmod +x tools/install_linux.sh 2>/dev/null || true
chmod +x tools/check_dependencies.py 2>/dev/null || true
chmod +x ea_launcher.py 2>/dev/null || true
chmod +x ea_workflow.py 2>/dev/null || true
chmod +x ea_optimizer.py 2>/dev/null || true

print_success "Permissions configurées"
echo ""

# Vérification de l'installation
echo "Vérification de l'installation..."
$PYTHON_CMD tools/check_dependencies.py
if [ $? -ne 0 ]; then
    echo ""
    print_warning "Certaines dépendances peuvent manquer"
fi
echo ""

# Fin
echo "========================================================================"
echo "  Installation terminée avec succès!"
echo "========================================================================"
echo ""
echo "Prochaines étapes:"
echo "  1. Configurez votre compte MT5 (via Wine si sur Linux/Mac)"
echo "  2. Lancez le workflow: $PYTHON_CMD ea_workflow.py"
echo "  3. Consultez la documentation: tools/docs/QUICKSTART.md"
echo ""
echo "Pour tester l'installation:"
echo "  $PYTHON_CMD ea_workflow.py"
echo ""

