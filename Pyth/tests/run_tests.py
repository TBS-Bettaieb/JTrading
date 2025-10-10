"""
Script de lancement des tests unitaires
"""
import pytest
import sys
import os
from pathlib import Path

def main():
    """Lance les tests unitaires avec différentes options"""
    
    # Ajouter le répertoire parent au path
    parent_dir = Path(__file__).parent.parent
    sys.path.insert(0, str(parent_dir))
    
    print("🧪 Tests unitaires - Système de Trading JTrading")
    print("=" * 60)
    
    # Options de test
    test_options = {
        'all': 'Tous les tests',
        'indicators': 'Tests des indicateurs techniques',
        'strategies': 'Tests des stratégies de trading',
        'backtesting': 'Tests du moteur de backtesting',
        'data_manager': 'Tests du gestionnaire de données',
        'config': 'Tests de la configuration',
        'integration': 'Tests d\'intégration end-to-end',
        'quick': 'Tests rapides (sans intégration)',
        'coverage': 'Tests avec couverture de code'
    }
    
    print("\nOptions disponibles:")
    for key, desc in test_options.items():
        print(f"  {key}: {desc}")
    
    # Sélection automatique ou manuelle
    if len(sys.argv) > 1:
        test_type = sys.argv[1]
    else:
        test_type = input("\nType de test à exécuter (ou 'all' pour tous): ").strip().lower()
    
    if test_type not in test_options:
        print(f"❌ Option invalide: {test_type}")
        print(f"Options disponibles: {', '.join(test_options.keys())}")
        return 1
    
    print(f"\n🚀 Exécution des tests: {test_options[test_type]}")
    print("-" * 60)
    
    # Configuration des arguments pytest
    pytest_args = []
    
    if test_type == 'all':
        pytest_args = ['tests/']
    elif test_type == 'quick':
        pytest_args = ['tests/', '-k', 'not integration']
    elif test_type == 'coverage':
        pytest_args = ['tests/', '--cov=.', '--cov-report=html', '--cov-report=term']
    else:
        pytest_args = [f'tests/test_{test_type}.py']
    
    # Options communes
    pytest_args.extend([
        '-v',  # Verbose
        '--tb=short',  # Traceback court
        '--color=yes',  # Couleurs
        '--durations=10'  # Afficher les 10 tests les plus lents
    ])
    
    # Exécuter les tests
    try:
        exit_code = pytest.main(pytest_args)
        
        if exit_code == 0:
            print("\n✅ Tous les tests sont passés avec succès!")
        else:
            print(f"\n❌ {exit_code} test(s) ont échoué")
            
        return exit_code
        
    except Exception as e:
        print(f"\n❌ Erreur lors de l'exécution des tests: {e}")
        return 1


def run_specific_test(test_file, test_function=None):
    """Lance un test spécifique"""
    pytest_args = [f'tests/{test_file}']
    
    if test_function:
        pytest_args.extend(['-k', test_function])
    
    pytest_args.extend(['-v', '--tb=short'])
    
    return pytest.main(pytest_args)


def run_quick_tests():
    """Lance les tests rapides"""
    pytest_args = [
        'tests/test_config.py',
        'tests/test_data_manager.py', 
        'tests/test_indicators.py',
        '-v', '--tb=short'
    ]
    
    return pytest.main(pytest_args)


def run_integration_tests():
    """Lance uniquement les tests d'intégration"""
    pytest_args = [
        'tests/test_integration.py',
        '-v', '--tb=short', '--durations=10'
    ]
    
    return pytest.main(pytest_args)


def run_coverage_report():
    """Génère un rapport de couverture"""
    pytest_args = [
        'tests/',
        '--cov=.',
        '--cov-report=html',
        '--cov-report=term-missing',
        '--cov-fail-under=80'  # Échec si couverture < 80%
    ]
    
    return pytest.main(pytest_args)


if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)
