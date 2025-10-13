#!/usr/bin/env python3
"""
Script de vérification des dépendances pour EA JTFreeCandle_v2
Vérifie que tous les packages nécessaires sont installés et fonctionnels
"""

import sys
from pathlib import Path

def print_header():
    """Affiche l'en-tête"""
    print("\n" + "="*70)
    print("  Vérification des Dépendances - EA JTFreeCandle_v2")
    print("="*70 + "\n")

def check_python_version():
    """Vérifie la version de Python"""
    print("[1/8] Vérification de la version Python...")
    version = sys.version_info
    
    if version.major == 3 and version.minor >= 8:
        print(f"✅ Python {version.major}.{version.minor}.{version.micro} - OK")
        return True
    else:
        print(f"❌ Python {version.major}.{version.minor}.{version.micro} - Version trop ancienne")
        print("   Python 3.8 ou supérieur est requis")
        return False

def check_package(package_name, import_name=None, required=True):
    """Vérifie si un package est installé"""
    if import_name is None:
        import_name = package_name
    
    try:
        module = __import__(import_name)
        version = getattr(module, '__version__', 'version inconnue')
        status = "✅" if required else "ℹ️"
        print(f"{status} {package_name} ({version}) - OK")
        return True
    except ImportError:
        status = "❌" if required else "⚠️"
        req_text = "REQUIS" if required else "Optionnel"
        print(f"{status} {package_name} - MANQUANT ({req_text})")
        return False

def check_core_packages():
    """Vérifie les packages Python essentiels"""
    print("\n[2/8] Vérification des packages Python essentiels...")
    
    packages = {
        'pandas': True,
        'numpy': True,
        'matplotlib': True,
        'seaborn': True,
    }
    
    all_ok = True
    for package, required in packages.items():
        if not check_package(package, required=required):
            all_ok = False
    
    return all_ok

def check_mt5_package():
    """Vérifie le package MetaTrader5"""
    print("\n[3/8] Vérification du package MetaTrader5...")
    
    try:
        import MetaTrader5 as mt5
        version = mt5.__version__ if hasattr(mt5, '__version__') else "version inconnue"
        print(f"✅ MetaTrader5 ({version}) - OK")
        return True
    except ImportError:
        print("❌ MetaTrader5 - MANQUANT (REQUIS)")
        print("   Installation: pip install MetaTrader5")
        return False

def check_optional_packages():
    """Vérifie les packages optionnels"""
    print("\n[4/8] Vérification des packages optionnels...")
    
    optional_packages = {
        'scipy': False,
        'scikit-learn': ('sklearn', False),
        'plotly': False,
    }
    
    for package_info in optional_packages.items():
        if isinstance(package_info[1], tuple):
            package, (import_name, required) = package_info[0], package_info[1]
            check_package(package, import_name, required)
        else:
            package, required = package_info
            check_package(package, required=required)

def check_project_structure():
    """Vérifie la structure du projet"""
    print("\n[5/8] Vérification de la structure du projet...")
    
    required_files = [
        'ea_launcher.py',
        'ea_workflow.py',
        'ea_optimizer.py',
        'requirements.txt',
    ]
    
    all_ok = True
    for file in required_files:
        if Path(file).exists():
            print(f"✅ {file} - Trouvé")
        else:
            print(f"❌ {file} - MANQUANT")
            all_ok = False
    
    return all_ok

def check_directories():
    """Vérifie les répertoires nécessaires"""
    print("\n[6/8] Vérification des répertoires...")
    
    dirs_to_check = [
        'EA_Workflow',
        'EA_Workflow/configs',
        'EA_Workflow/set_files',
        'EA_Workflow/reports',
        'EA_Workflow/results',
    ]
    
    for directory in dirs_to_check:
        dir_path = Path(directory)
        if dir_path.exists():
            print(f"✅ {directory}/ - Existe")
        else:
            print(f"⚠️  {directory}/ - N'existe pas (sera créé au besoin)")

def check_mt5_connection():
    """Vérifie la connexion à MT5"""
    print("\n[7/8] Vérification de la connexion MetaTrader5...")
    
    try:
        import MetaTrader5 as mt5
        
        if mt5.initialize():
            version = mt5.version()
            print(f"✅ MT5 connecté - Version: {version}")
            
            # Informations sur le compte
            account_info = mt5.account_info()
            if account_info:
                print(f"ℹ️  Compte: {account_info.login}")
                print(f"ℹ️  Serveur: {account_info.server}")
            
            mt5.shutdown()
            return True
        else:
            print("⚠️  MT5 non connecté")
            print("   MetaTrader 5 doit être ouvert et connecté à un compte")
            return False
    except Exception as e:
        print(f"❌ Erreur de connexion MT5: {e}")
        return False

def check_documentation():
    """Vérifie la présence de la documentation"""
    print("\n[8/8] Vérification de la documentation...")
    
    docs = [
        'tools/docs/INSTALLATION.md',
        'tools/docs/QUICKSTART.md',
        'README_WORKFLOW.md',
    ]
    
    for doc in docs:
        if Path(doc).exists():
            print(f"✅ {doc} - Disponible")
        else:
            print(f"⚠️  {doc} - Non trouvé")

def print_summary(results):
    """Affiche le résumé"""
    print("\n" + "="*70)
    print("  RÉSUMÉ")
    print("="*70 + "\n")
    
    all_required_ok = all(results.values())
    
    if all_required_ok:
        print("✅ Toutes les dépendances requises sont installées!")
        print("\nVous pouvez maintenant utiliser:")
        print("  • python ea_launcher.py    - Lanceur d'EA")
        print("  • python ea_workflow.py    - Workflow complet")
        print("  • python ea_optimizer.py   - Optimiseur")
    else:
        print("❌ Certaines dépendances requises sont manquantes")
        print("\nInstallez les dépendances manquantes:")
        print("  pip install -r requirements.txt")
    
    print("\n" + "="*70 + "\n")
    
    return 0 if all_required_ok else 1

def main():
    """Fonction principale"""
    print_header()
    
    results = {
        'python': check_python_version(),
        'packages': check_core_packages(),
        'mt5': check_mt5_package(),
    }
    
    check_optional_packages()
    check_project_structure()
    check_directories()
    
    # Ne pas considérer la connexion MT5 comme requise pour l'installation
    mt5_connected = check_mt5_connection()
    if not mt5_connected:
        print("\nℹ️  Note: MT5 n'est pas connecté, mais ce n'est pas un problème pour l'installation.")
        print("   Assurez-vous que MT5 est ouvert et connecté avant d'utiliser les scripts.")
    
    check_documentation()
    
    return print_summary(results)

if __name__ == "__main__":
    sys.exit(main())

