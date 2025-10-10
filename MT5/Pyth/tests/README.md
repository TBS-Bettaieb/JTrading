# Tests Unitaires - Système de Trading JTrading

Ce répertoire contient tous les tests unitaires et d'intégration pour le système de trading JTrading.

## Structure des Tests

```
tests/
├── __init__.py              # Module de tests
├── conftest.py              # Fixtures communes et configuration
├── pytest.ini              # Configuration pytest
├── run_tests.py            # Script de lancement des tests
├── README.md               # Ce fichier
├── test_config.py          # Tests de configuration
├── test_indicators.py      # Tests des indicateurs techniques
├── test_strategies.py      # Tests des stratégies de trading
├── test_backtesting.py     # Tests du moteur de backtesting
├── test_data_manager.py    # Tests du gestionnaire de données
├── test_integration.py     # Tests d'intégration end-to-end
```

## Types de Tests

### 1. Tests Unitaires
- **`test_config.py`**: Tests de la configuration et validation des paramètres
- **`test_indicators.py`**: Tests des indicateurs techniques (Bollinger, RSI, EMA, ATR)
- **`test_strategies.py`**: Tests des stratégies de trading (FreeCandle, Divergence)
- **`test_backtesting.py`**: Tests du moteur de backtesting et des métriques
- **`test_data_manager.py`**: Tests du gestionnaire de données et validation

### 2. Tests d'Intégration
- **`test_integration.py`**: Tests end-to-end du workflow complet

## Fixtures Disponibles

Le fichier `conftest.py` fournit des fixtures communes :

- `sample_ohlcv_data`: Données OHLCV d'exemple (1000 barres)
- `sample_ohlcv_data_with_gaps`: Données avec gaps pour tester la gestion des données manquantes
- `default_config`: Configuration par défaut
- `conservative_config`: Configuration conservatrice
- `aggressive_config`: Configuration agressive
- `sample_trades`: Trades d'exemple pour les tests
- `sample_signals`: Signaux d'exemple pour les tests

## Exécution des Tests

### 1. Lancement Simple
```bash
# Tous les tests
python tests/run_tests.py

# Tests spécifiques
python tests/run_tests.py indicators
python tests/run_tests.py strategies
python tests/run_tests.py backtesting
python tests/run_tests.py integration
```

### 2. Avec Pytest Directement
```bash
# Tous les tests
pytest tests/

# Tests spécifiques
pytest tests/test_indicators.py
pytest tests/test_strategies.py -v

# Tests avec couverture
pytest tests/ --cov=. --cov-report=html
```

### 3. Options Avancées
```bash
# Tests rapides (sans intégration)
python tests/run_tests.py quick

# Tests avec couverture de code
python tests/run_tests.py coverage

# Tests avec filtres
pytest tests/ -k "test_bollinger" -v
pytest tests/ -m "not slow" -v
```

## Marqueurs de Tests

Les tests sont marqués pour faciliter l'exécution sélective :

- `@pytest.mark.slow`: Tests lents
- `@pytest.mark.integration`: Tests d'intégration
- `@pytest.mark.unit`: Tests unitaires
- `@pytest.mark.indicators`: Tests d'indicateurs
- `@pytest.mark.strategies`: Tests de stratégies

## Exemples d'Utilisation

### Test d'un Indicateur
```python
def test_bollinger_bands_basic(self, sample_ohlcv_data):
    """Test de base pour Bollinger Bands"""
    bb = BollingerBands(period=20, deviation=2.0)
    result = bb.calculate(sample_ohlcv_data)
    
    assert 'bb_upper' in result.columns
    assert (result['bb_upper'] >= result['bb_middle']).all()
```

### Test d'une Stratégie
```python
def test_generate_signals_basic(self, sample_ohlcv_data, conservative_config):
    """Test de génération de signaux de base"""
    strategy = FreeCandleStrategy(conservative_config)
    signals = strategy.generate_signals(sample_ohlcv_data)
    
    assert isinstance(signals, list)
    if signals:
        for signal in signals:
            assert isinstance(signal, Signal)
            assert signal.direction in [-1, 1]
```

### Test d'Intégration
```python
def test_full_trading_workflow(self, sample_ohlcv_data, conservative_config):
    """Test du workflow complet de trading"""
    # 1. Configuration
    config = conservative_config
    
    # 2. Génération des signaux
    strategy = FreeCandleStrategy(config)
    signals = strategy.generate_signals(sample_ohlcv_data)
    
    # 3. Backtesting
    engine = BacktestEngine(initial_capital=10000, commission=0.0002)
    results = engine.run_backtest(sample_ohlcv_data, signals, config)
    
    # 4. Analyse de performance
    analyzer = PerformanceAnalyzer()
    report = analyzer.generate_report(results, save_to_file=False)
    
    assert results is not None
    assert report is not None
```

## Couverture de Code

Pour générer un rapport de couverture :

```bash
pytest tests/ --cov=. --cov-report=html --cov-report=term
```

Le rapport HTML sera généré dans `htmlcov/index.html`.

## Bonnes Pratiques

### 1. Structure des Tests
- Un fichier de test par module principal
- Tests organisés par classe de fonctionnalité
- Noms de tests descriptifs et explicites

### 2. Fixtures
- Utiliser les fixtures communes quand possible
- Créer des fixtures spécifiques pour des cas particuliers
- Éviter la duplication de code de setup

### 3. Assertions
- Assertions spécifiques et claires
- Tester les cas limites et les erreurs
- Vérifier les types et les valeurs

### 4. Données de Test
- Données reproductibles (seed fixe)
- Données réalistes mais contrôlées
- Tests avec différentes tailles de données

## Dépannage

### Erreurs Communes

1. **ImportError**: Vérifier que le PYTHONPATH inclut le répertoire parent
2. **ModuleNotFoundError**: S'assurer que tous les modules sont installés
3. **AssertionError**: Vérifier la logique des assertions et les données de test

### Debug des Tests

```bash
# Mode verbose pour plus de détails
pytest tests/test_indicators.py -v -s

# Arrêter au premier échec
pytest tests/ -x

# Afficher les print statements
pytest tests/ -s

# Tests spécifiques avec debug
pytest tests/test_indicators.py::TestBollingerBands::test_bollinger_bands_basic -v -s
```

## Intégration Continue

Les tests sont conçus pour s'intégrer dans un pipeline CI/CD :

```yaml
# Exemple GitHub Actions
- name: Run Tests
  run: |
    pip install -r requirements.txt
    python tests/run_tests.py all
    
- name: Generate Coverage
  run: |
    python tests/run_tests.py coverage
```

## Contribution

Lors de l'ajout de nouvelles fonctionnalités :

1. Créer les tests correspondants
2. Maintenir une couverture de code > 80%
3. Documenter les nouveaux tests
4. Utiliser des fixtures existantes quand possible
5. Tester les cas limites et les erreurs
