# 🛠️ Configuration de Compilation MQL5 dans VS Code

## ✅ Configuration Terminée

La compilation MQL5 via MetaEditor est maintenant configurée dans VS Code.

### 📁 Fichiers Créés

- `.vscode/tasks.json` - Configuration de la tâche de compilation
- `build/mql5-compile.log` - Fichier de log pour les erreurs de compilation
- `build/README_COMPILATION.md` - Ce guide

### 🚀 Utilisation

#### Méthode 1 : Raccourci Clavier
1. Ouvrir un fichier `.mq5` dans VS Code
2. Appuyer sur `Ctrl+Shift+B` (Build)

#### Méthode 2 : Palette de Commandes
1. Ouvrir un fichier `.mq5` dans VS Code
2. `Ctrl+Shift+P` puis taper "Tasks: Run Task"
3. Sélectionner "Compile MQL5"

### ⚙️ Configuration

Le fichier `.vscode/tasks.json` contient :
- **Commande** : `C:\Program Files\MetaTrader 5\metaeditor64.exe`
- **Arguments** : `/compile:${file}` et `/log:${workspaceFolder}\build\mql5-compile.log`
- **ProblemMatcher** : Parse automatiquement les erreurs MQL5

### 🔍 Analyse des Erreurs

Les erreurs de compilation seront automatiquement :
- Parsées depuis le fichier de log
- Affichées dans le panneau "Problems" de VS Code
- Liées directement aux lignes de code source

### 🛠️ Dépannage

**Chemin actuel configuré :** `C:\Program Files\FTMO Global Markets MT5 Terminal\MetaEditor64.exe`

Si MetaEditor n'est pas trouvé, modifier le chemin dans `.vscode/tasks.json` ligne 10.

**Chemins alternatifs possibles :**
- `C:\Program Files\MetaTrader 5\metaeditor64.exe`
- `C:\Program Files\MetaTrader 5\metaeditor.exe` 
- `C:\Program Files (x86)\MetaTrader 5\metaeditor64.exe`
- `C:\Program Files\FTMO Global Markets MT5 Terminal\MetaEditor64.exe` *(actuel)*

### ⚠️ Important

- **Seuls les fichiers `.mq5` peuvent être compilés**
- Les fichiers `.mqh` (headers) ne peuvent pas être compilés directement
- La tâche affichera une erreur si vous tentez de compiler un fichier `.mqh`
