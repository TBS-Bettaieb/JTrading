"""
Test d'installation - Vérification de l'environnement Python
"""
import sys

def test_imports():
    """Teste l'importation de tous les modules requis"""
    
    print("=" * 60)
    print("TEST D'INSTALLATION - ENVIRONNEMENT PYTHON")
    print("=" * 60)
    print()
    
    modules = {
        "Core": ["numpy", "pandas", "scipy"],
        "Trading": ["MetaTrader5"],
        "Indicateurs": ["ta"],
        "Visualisation": ["matplotlib", "seaborn", "plotly"],
        "Machine Learning": ["sklearn"],
        "Utilitaires": ["tqdm", "colorama", "tabulate", "loguru", "yaml", "dotenv"],
        "Tests": ["pytest"]
    }
    
    all_ok = True
    
    for category, module_list in modules.items():
        print(f"\n📦 {category}:")
        print("-" * 60)
        
        for module in module_list:
            try:
                if module == "sklearn":
                    import sklearn
                    version = sklearn.__version__
                elif module == "yaml":
                    import yaml
                    version = yaml.__version__ if hasattr(yaml, '__version__') else "OK"
                elif module == "dotenv":
                    import dotenv
                    version = dotenv.__version__ if hasattr(dotenv, '__version__') else "OK"
                else:
                    mod = __import__(module)
                    version = mod.__version__ if hasattr(mod, '__version__') else "OK"
                
                print(f"  ✅ {module:20s} v{version}")
                
            except ImportError as e:
                print(f"  ❌ {module:20s} ERREUR: {e}")
                all_ok = False
    
    print("\n" + "=" * 60)
    
    # Test MetaTrader5 spécifique
    print("\n🔌 TEST METATRADER 5:")
    print("-" * 60)
    try:
        import MetaTrader5 as mt5
        print(f"  ✅ MetaTrader5 importé avec succès")
        print(f"  📌 Version: {mt5.__version__}")
        print(f"  📌 Author: {mt5.__author__}")
        
        # Note: Ne pas tenter de connexion ici car MT5 peut ne pas être lancé
        print("\n  ⚠️  Pour tester la connexion MT5, lancez MetaTrader 5")
        print("      puis exécutez: python -c 'import MetaTrader5 as mt5; mt5.initialize()'")
        
    except Exception as e:
        print(f"  ❌ Erreur MetaTrader5: {e}")
        all_ok = False
    
    print("\n" + "=" * 60)
    print(f"\n🐍 Python {sys.version}")
    print(f"📁 Chemin: {sys.executable}")
    print("=" * 60)
    
    if all_ok:
        print("\n✅ INSTALLATION COMPLÈTE ET FONCTIONNELLE!")
        print("\n🚀 Prochaines étapes:")
        print("   1. Vérifiez que MetaTrader 5 est installé et lancé")
        print("   2. Testez la connexion: python test_mt5_connection.py")
        print("   3. Lancez un backtest: python backtest.py")
        print("   4. Ou utilisez le menu: python main.py")
    else:
        print("\n❌ CERTAINS MODULES SONT MANQUANTS")
        print("   Réexécutez: pip install -r requirements.txt")
    
    print()
    return all_ok


if __name__ == "__main__":
    success = test_imports()
    sys.exit(0 if success else 1)

