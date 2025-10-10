"""
Script de vérification rapide du système
Usage: python check_system.py
"""
import sys
import os


def check_system():
    """Vérification rapide de l'état du système"""
    
    print("╔══════════════════════════════════════════════════════════════╗")
    print("║           VÉRIFICATION SYSTÈME - JTRADING PYTHON             ║")
    print("╚══════════════════════════════════════════════════════════════╝")
    print()
    
    all_ok = True
    
    # 1. Python
    print("🐍 PYTHON")
    print("-" * 60)
    print(f"  Version: {sys.version.split()[0]}")
    print(f"  Chemin: {sys.executable}")
    
    if sys.version_info >= (3, 11):
        print("  ✅ Version OK (>= 3.11)")
    else:
        print("  ❌ Version trop ancienne, recommandé: 3.11+")
        all_ok = False
    print()
    
    # 2. Modules critiques
    print("📦 MODULES CRITIQUES")
    print("-" * 60)
    
    critical_modules = [
        ("numpy", "NumPy"),
        ("pandas", "Pandas"),
        ("MetaTrader5", "MetaTrader5"),
        ("matplotlib", "Matplotlib"),
        ("ta", "TA"),
    ]
    
    for module, name in critical_modules:
        try:
            mod = __import__(module)
            version = getattr(mod, '__version__', 'OK')
            print(f"  ✅ {name:20s} v{version}")
        except ImportError:
            print(f"  ❌ {name:20s} MANQUANT")
            all_ok = False
    print()
    
    # 3. Structure du projet
    print("📁 STRUCTURE DU PROJET")
    print("-" * 60)
    
    required_dirs = [
        "config",
        "indicators",
        "strategies",
        "risk_management",
        "backtesting",
        "live_trading",
        "data",
        "analysis",
        "utils"
    ]
    
    for dir_name in required_dirs:
        if os.path.isdir(dir_name):
            files = [f for f in os.listdir(dir_name) if f.endswith('.py')]
            print(f"  ✅ {dir_name:20s} ({len(files)} fichiers)")
        else:
            print(f"  ❌ {dir_name:20s} MANQUANT")
            all_ok = False
    print()
    
    # 4. Fichiers principaux
    print("📄 FICHIERS PRINCIPAUX")
    print("-" * 60)
    
    required_files = [
        "main.py",
        "backtest.py",
        "live_trade.py",
        "requirements.txt",
        "README.md"
    ]
    
    for file_name in required_files:
        if os.path.isfile(file_name):
            size = os.path.getsize(file_name) / 1024
            print(f"  ✅ {file_name:25s} ({size:.1f} KB)")
        else:
            print(f"  ❌ {file_name:25s} MANQUANT")
            all_ok = False
    print()
    
    # 5. MetaTrader5
    print("🔌 METATRADER 5")
    print("-" * 60)
    try:
        import MetaTrader5 as mt5
        print(f"  ✅ Module installé: v{mt5.__version__}")
        
        if mt5.initialize():
            print("  ✅ Connexion réussie")
            account = mt5.account_info()
            if account:
                print(f"  ✅ Compte: {account.login} ({account.server})")
                print(f"  ✅ Balance: {account.balance:.2f} {account.currency}")
            mt5.shutdown()
        else:
            print("  ⚠️  MT5 non connecté (normal si non lancé)")
    except Exception as e:
        print(f"  ❌ Erreur: {e}")
        all_ok = False
    print()
    
    # Résumé
    print("=" * 60)
    if all_ok:
        print("✅ SYSTÈME OPÉRATIONNEL")
        print()
        print("Commandes disponibles:")
        print("  python main.py           → Menu principal")
        print("  python backtest.py       → Lancer un backtest")
        print("  python live_trade.py     → Trading en direct")
    else:
        print("❌ PROBLÈMES DÉTECTÉS")
        print()
        print("Actions recommandées:")
        print("  pip install -r requirements.txt")
        print("  python test_installation.py")
    print("=" * 60)
    
    return all_ok


if __name__ == "__main__":
    success = check_system()
    sys.exit(0 if success else 1)

