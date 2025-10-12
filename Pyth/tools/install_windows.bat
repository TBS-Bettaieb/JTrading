@echo off
REM ============================================================================
REM Installation automatique EA JTFreeCandle_v2 - Windows
REM ============================================================================

echo.
echo ========================================================================
echo   EA JTFreeCandle_v2 - Installation Automatique pour Windows
echo ========================================================================
echo.

REM Verification des privileges administrateur
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [AVERTISSEMENT] Certaines operations peuvent necessiter les droits administrateur.
    echo.
)

REM Etape 1: Verification Python
echo [1/6] Verification de Python...
python --version >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERREUR] Python n'est pas installe ou n'est pas dans le PATH
    echo.
    echo Telechargez Python depuis: https://www.python.org/downloads/
    echo Assurez-vous de cocher "Add Python to PATH" lors de l'installation
    pause
    exit /b 1
)

python --version
echo [OK] Python est installe
echo.

REM Etape 2: Verification pip
echo [2/6] Verification de pip...
pip --version >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERREUR] pip n'est pas disponible
    echo Installation de pip...
    python -m ensurepip --upgrade
)
echo [OK] pip est disponible
echo.

REM Etape 3: Installation des dependances
echo [3/6] Installation des dependances Python...
echo.

if exist requirements.txt (
    echo Installation depuis requirements.txt...
    pip install -r requirements.txt
    if %errorLevel% neq 0 (
        echo [ERREUR] Echec de l'installation des dependances
        pause
        exit /b 1
    )
) else (
    echo [AVERTISSEMENT] requirements.txt non trouve
    echo Installation des packages essentiels...
    pip install pandas numpy matplotlib seaborn MetaTrader5
)

echo [OK] Dependances installees
echo.

REM Etape 4: Verification MetaTrader 5
echo [4/6] Verification de MetaTrader 5...

set MT5_FOUND=0

REM Recherche dans les emplacements courants
if exist "C:\Program Files\MetaTrader 5\terminal64.exe" (
    set MT5_PATH=C:\Program Files\MetaTrader 5\terminal64.exe
    set MT5_FOUND=1
)

if exist "C:\Program Files (x86)\MetaTrader 5\terminal64.exe" (
    set MT5_PATH=C:\Program Files ^(x86^)\MetaTrader 5\terminal64.exe
    set MT5_FOUND=1
)

REM Recherche dans AppData
for /d %%D in ("%APPDATA%\MetaQuotes\Terminal\*") do (
    if exist "%%D\terminal64.exe" (
        set MT5_PATH=%%D\terminal64.exe
        set MT5_FOUND=1
    )
)

if %MT5_FOUND%==1 (
    echo [OK] MetaTrader 5 trouve: %MT5_PATH%
) else (
    echo [AVERTISSEMENT] MetaTrader 5 non trouve
    echo.
    echo Telechargez MT5 depuis: https://www.metatrader5.com/
    echo.
)
echo.

REM Etape 5: Creation des dossiers necessaires
echo [5/6] Creation des dossiers de travail...

if not exist "EA_Workflow" mkdir EA_Workflow
if not exist "EA_Workflow\configs" mkdir EA_Workflow\configs
if not exist "EA_Workflow\set_files" mkdir EA_Workflow\set_files
if not exist "EA_Workflow\reports" mkdir EA_Workflow\reports
if not exist "EA_Workflow\results" mkdir EA_Workflow\results

if not exist "MT5_Sets" mkdir MT5_Sets

echo [OK] Dossiers crees:
echo   - EA_Workflow/
echo   - EA_Workflow/configs/
echo   - EA_Workflow/set_files/
echo   - EA_Workflow/reports/
echo   - EA_Workflow/results/
echo   - MT5_Sets/
echo.

REM Etape 6: Verification de l'installation
echo [6/6] Verification de l'installation...
python tools\check_dependencies.py
if %errorLevel% neq 0 (
    echo.
    echo [AVERTISSEMENT] Certaines dependances peuvent manquer
)
echo.

REM Fin
echo ========================================================================
echo   Installation terminee avec succes!
echo ========================================================================
echo.
echo Prochaines etapes:
echo   1. Configurez votre compte MT5
echo   2. Lancez le workflow: python ea_workflow.py
echo   3. Consultez la documentation: tools\docs\QUICKSTART.md
echo.
echo Pour tester l'installation:
echo   python ea_workflow.py
echo.

pause

