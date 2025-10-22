# JT_TradeTracker - Utilisation du dossier Common Files

## 📋 Modifications appliquées

Le `JT_TradeTracker.mqh` a été modifié pour sauvegarder tous les fichiers CSV dans le **dossier Common Files** de MT5 au lieu du dossier spécifique de chaque terminal.

### 🔧 Changements techniques

Ajout du flag `FILE_COMMON` à tous les appels `FileOpen()`:

1. **Ligne 522** - Lecture pour vérification d'existence:
   ```cpp
   m_fileHandle = FileOpen(m_csvFile, FILE_READ|FILE_COMMON|FILE_ANSI);
   ```

2. **Ligne 532** - Création avec écriture d'en-tête:
   ```cpp
   m_fileHandle = FileOpen(m_csvFile, FILE_WRITE|FILE_COMMON|FILE_ANSI);
   ```

3. **Ligne 560** - Ajout de lignes (mode append):
   ```cpp
   int handle = FileOpen(m_csvFile, FILE_WRITE|FILE_READ|FILE_COMMON|FILE_ANSI);
   ```

### 📂 Emplacement des fichiers CSV

**Avant:**
```
C:\Users\[User]\AppData\Roaming\MetaQuotes\Terminal\
    [Terminal_ID]\MQL5\Files\TradeAnalysis_EURUSD_H1.csv
```

**Après:**
```
C:\Users\[User]\AppData\Roaming\MetaQuotes\Terminal\
    Common\Files\TradeAnalysis_EURUSD_H1.csv
```

### ✅ Avantages

1. **Accessibilité universelle**: Les CSV sont accessibles depuis tous les terminaux MT5
2. **Simplicité d'accès**: Un seul dossier pour tous les fichiers CSV
3. **Compatibilité Python**: Plus facile d'accéder aux fichiers depuis le backtester Python
4. **Cohérence**: Même comportement que `EA_ExportHistoryCsv.mq5`

### 🔍 Comment trouver vos fichiers CSV

#### Méthode 1: Chemin direct
```
%APPDATA%\MetaQuotes\Terminal\Common\Files\
```

#### Méthode 2: Depuis MT5
1. Ouvrir MT5
2. Menu **Fichier** → **Ouvrir le dossier de données**
3. Naviguer vers `Common\Files\`

#### Méthode 3: Depuis Python
```python
import os

common_files = os.path.join(
    os.getenv('APPDATA'),
    'MetaQuotes', 'Terminal', 'Common', 'Files'
)

csv_file = os.path.join(common_files, 'TradeAnalysis_EURUSD_H1.csv')
```

### 📊 Format des noms de fichiers

Les fichiers sont nommés selon le format:
```
TradeAnalysis_[Symbol]_[Timeframe].csv
```

Exemples:
- `TradeAnalysis_EURUSD_H1.csv`
- `TradeAnalysis_GBPUSD_H4.csv`
- `TradeAnalysis_US100.cash_M3.csv`

### 🐛 Résolution de problèmes

#### Fichier non créé
**Symptôme**: Aucun CSV dans Common\Files\

**Solutions**:
1. Vérifier les permissions d'écriture du dossier
2. Vérifier les logs MT5 pour les erreurs
3. S'assurer que l'EA a bien été démarré

#### Ancien CSV dans MQL5\Files
**Symptôme**: CSV présent dans l'ancien emplacement

**Solution**:
1. Les anciens fichiers restent à l'ancien emplacement
2. Les nouveaux fichiers sont créés dans Common\Files\
3. Vous pouvez supprimer les anciens fichiers manuellement

#### Accès depuis Python
**Symptôme**: Python ne trouve pas le fichier

**Solution**:
```python
# Utiliser le chemin complet
import os
csv_path = os.path.join(
    os.getenv('APPDATA'),
    'MetaQuotes', 'Terminal', 'Common', 'Files',
    'TradeAnalysis_EURUSD_H1.csv'
)

if os.path.exists(csv_path):
    df = pd.read_csv(csv_path)
else:
    print(f"Fichier non trouvé: {csv_path}")
```

### 🔄 Migration des anciens fichiers

Si vous avez des fichiers CSV dans l'ancien emplacement:

#### Option 1: Laisser tel quel
- Les anciens fichiers restent accessibles
- Les nouveaux trades vont dans le nouveau dossier Common

#### Option 2: Copier manuellement
```batch
:: Windows CMD
copy "%APPDATA%\MetaQuotes\Terminal\[Terminal_ID]\MQL5\Files\*.csv" ^
     "%APPDATA%\MetaQuotes\Terminal\Common\Files\"
```

#### Option 3: Script Python
```python
import os
import shutil
from pathlib import Path

# Chemin source (remplacer [Terminal_ID])
source = Path(os.getenv('APPDATA')) / 'MetaQuotes' / 'Terminal' / '[Terminal_ID]' / 'MQL5' / 'Files'

# Chemin destination
dest = Path(os.getenv('APPDATA')) / 'MetaQuotes' / 'Terminal' / 'Common' / 'Files'

# Copier tous les CSV
for csv_file in source.glob('TradeAnalysis_*.csv'):
    shutil.copy(csv_file, dest / csv_file.name)
    print(f"Copié: {csv_file.name}")
```

### 📝 Notes importantes

1. **Pas de changement pour l'EA**: L'EA fonctionne exactement de la même manière
2. **Backward compatible**: Les anciens fichiers restent accessibles
3. **Thread-safe**: Le système gère correctement les écritures concurrentes
4. **Pas de perte de données**: Tout continue de fonctionner normalement

### 🔗 Intégration avec le backtester Python

Le backtester peut maintenant accéder facilement aux CSV:

```python
from ea_launcher import MT5EALauncher
import os

# Chemin Common Files
common_files = os.path.join(
    os.getenv('APPDATA'),
    'MetaQuotes', 'Terminal', 'Common', 'Files'
)

# Lister tous les CSV disponibles
import glob
csv_files = glob.glob(os.path.join(common_files, 'TradeAnalysis_*.csv'))

for csv in csv_files:
    print(f"CSV trouvé: {os.path.basename(csv)}")
```

### ✅ Vérification de la modification

Pour vérifier que la modification fonctionne:

1. **Lancer l'EA** sur un graphique
2. **Attendre un trade**
3. **Vérifier le log MT5**:
   ```
   ✅ Nouveau fichier CSV créé dans Common Files: TradeAnalysis_EURUSD_H1.csv
   ```
4. **Ouvrir le dossier**:
   ```
   %APPDATA%\MetaQuotes\Terminal\Common\Files\
   ```
5. **Confirmer** que le fichier CSV est présent

---

**Date de modification**: 12 octobre 2025  
**Version**: Compatible avec JTFreeCandle_v2  
**Testé sur**: MT5 Build 4360+

