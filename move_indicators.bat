@echo off
echo ========================================
echo   COPIE DES INDICATEURS MQ5
echo ========================================
echo.

REM --- Configuration des chemins ---
set "SOURCE_DIR=%~dp0MT5\Indicators"

REM --- Chemin de destination (modifiez si necessaire) ---
REM Option 1: Chemin relatif (recommandé)
set "DEST_DIR=%~dp0..\..\..\MQL5\Indicators\JTIndicators"

REM Option 2: Chemin absolu (décommentez et modifiez si le relatif ne fonctionne pas)
REM set "DEST_DIR=C:\Users\taieb\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Indicators\JTIndicators"

echo Source: %SOURCE_DIR%
echo Destination: %DEST_DIR%
echo.

REM --- Affichage du chemin absolu pour verification ---
for %%i in ("%DEST_DIR%") do set "DEST_ABS=%%~fi"
echo Chemin absolu destination: %DEST_ABS%
echo.

REM --- Verification de l'existence du dossier source ---
if not exist "%SOURCE_DIR%" (
    echo ERREUR: Le dossier source n'existe pas: %SOURCE_DIR%
    echo.
    pause
    exit /b 1
)

REM --- Creation du dossier destination si inexistant ---
if not exist "%DEST_DIR%" (
    echo Creation du dossier destination...
    mkdir "%DEST_DIR%"
    if errorlevel 1 (
        echo ERREUR: Impossible de creer le dossier destination
        pause
        exit /b 1
    )
    echo Dossier cree avec succes.
    echo.
)

REM --- Comptage des fichiers .mq5 ---
set /a file_count=0
for %%f in ("%SOURCE_DIR%\*.mq5") do set /a file_count+=1

if %file_count%==0 (
    echo Aucun fichier .mq5 trouve dans le dossier source.
    echo.
    pause
    exit /b 0
)

echo %file_count% fichier(s) .mq5 trouve(s) a copier.
echo.

REM --- Copie des fichiers ---
echo Copie en cours...
echo.

for %%f in ("%SOURCE_DIR%\*.mq5") do (
    set "filename=%%~nxf"
    echo Copie: !filename!
    
    REM --- Copie du fichier .mq5 ---
    copy "%%f" "%DEST_DIR%\" >nul 2>&1
    if errorlevel 1 (
        echo   ERREUR: Impossible de copier !filename!
    ) else (
        echo   OK: !filename! copie avec succes
    )
    
    REM --- Copie du fichier .ex5 correspondant si existe ---
    set "ex5_file=%%~dpnf.ex5"
    if exist "!ex5_file!" (
        echo   Copie: !filename:.mq5=.ex5!
        copy "!ex5_file!" "%DEST_DIR%\" >nul 2>&1
        if errorlevel 1 (
            echo   ERREUR: Impossible de copier !filename:.mq5=.ex5!
        ) else (
            echo   OK: !filename:.mq5=.ex5! copie avec succes
        )
    )
    echo.
)

echo ========================================
echo   COPIE TERMINEE
echo ========================================
echo.
echo Les indicateurs ont ete copies vers:
echo %DEST_DIR%
echo.
echo Les fichiers originaux sont conserves dans:
echo %SOURCE_DIR%
echo.
echo N'oubliez pas de:
echo 1. Compiler les fichiers .mq5 dans MetaEditor
echo 2. Redemarrer MetaTrader 5 pour voir les nouveaux indicateurs
echo.

pause
