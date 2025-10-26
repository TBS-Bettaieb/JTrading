#!/usr/bin/env python3
"""
Test rapide de l'extracteur MT5 v2.0
====================================
Script de test simple pour vérifier le bon fonctionnement
"""

import sys
from pathlib import Path

def test_imports():
    """Test des imports."""
    print("🔍 Test des imports...")
    
    try:
        import pandas as pd
        print("✅ pandas")
    except ImportError as e:
        print(f"❌ pandas : {e}")
        return False
    
    try:
        import openpyxl
        print("✅ openpyxl")
    except ImportError as e:
        print(f"❌ openpyxl : {e}")
        return False
    
    try:
        import matplotlib.pyplot as plt
        print("✅ matplotlib")
    except ImportError as e:
        print(f"❌ matplotlib : {e}")
        return False
    
    try:
        import seaborn as sns
        print("✅ seaborn")
    except ImportError as e:
        print(f"❌ seaborn : {e}")
        return False
    
    try:
        import numpy as np
        print("✅ numpy")
    except ImportError as e:
        print(f"❌ numpy : {e}")
        return False
    
    try:
        from tqdm import tqdm
        print("✅ tqdm")
    except ImportError as e:
        print(f"❌ tqdm : {e}")
        return False
    
    return True

def test_extractor():
    """Test de l'extracteur."""
    print("\n🔍 Test de l'extracteur MT5...")
    
    try:
        from mt5_data_extractor import MT5DataExtractor
        print("✅ MT5DataExtractor importé")
    except ImportError as e:
        print(f"❌ Import extracteur : {e}")
        return False
    
    # Test d'initialisation
    try:
        extractor = MT5DataExtractor('test.xlsx', show_progress=False)
        print("✅ Initialisation réussie")
    except Exception as e:
        print(f"❌ Initialisation : {e}")
        return False
    
    return True

def main():
    """Fonction principale."""
    print("🧪 Test rapide de l'extracteur MT5 v2.0")
    print("=" * 50)
    
    # Test des imports
    if not test_imports():
        print("\n❌ Échec des tests d'import")
        print("💡 Installez les dépendances avec : pip install -r requirements.txt")
        return
    
    # Test de l'extracteur
    if not test_extractor():
        print("\n❌ Échec des tests de l'extracteur")
        return
    
    print("\n🎉 Tous les tests sont passés !")
    print("✅ L'extracteur MT5 v2.0 est prêt à l'emploi")
    print("\n💡 Utilisation :")
    print("   python example_mt5_extractor.py")
    print("   ou ouvrez MT5_Data_Analysis.ipynb dans Jupyter")

if __name__ == "__main__":
    main()
