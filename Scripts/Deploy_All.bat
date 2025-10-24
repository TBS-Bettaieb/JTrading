@echo off
REM +------------------------------------------------------------------+
REM |                                        Deploy_All.bat              |
REM |                         RSI Divergence Trading System              |
REM |                        Script de déploiement complet              |
REM +------------------------------------------------------------------+
REM | Version: 1.0                                                     |
REM | Usage: Deploy_All.bat                                            |
REM +------------------------------------------------------------------+

setlocal enabledelayedexpansion

echo 🚀 Déploiement complet du système RSI Divergence
echo ===============================================

REM Configuration des chemins
set "SHARED_SOURCE_PATH=.\Shared"
set "SHARED_TARGET_PATH=..\..\MQL5\Shared"
set "INDICATORS_SOURCE_PATH=.\Indicators"
set "INDICATORS_TARGET_PATH=..\..\MQL5\Indicators"
set "EA_SOURCE_PATH=.\EA"
set "EA_TARGET_PATH=..\..\MQL5\Experts"

REM Créer les dossiers de destination s'ils n'existent pas
if not exist "%SHARED_TARGET_PATH%" (
    echo 📁 Création du dossier: %SHARED_TARGET_PATH%
    mkdir "%SHARED_TARGET_PATH%" 2>nul
)
if not exist "%INDICATORS_TARGET_PATH%" (
    echo 📁 Création du dossier: %INDICATORS_TARGET_PATH%
    mkdir "%INDICATORS_TARGET_PATH%" 2>nul
)
if not exist "%EA_TARGET_PATH%" (
    echo 📁 Création du dossier: %EA_TARGET_PATH%
    mkdir "%EA_TARGET_PATH%" 2>nul
)

REM Copier les dépendances partagées
echo 📦 Copie des dépendances partagées...
for %%F in ("%SHARED_SOURCE_PATH%\*.mqh") do (
    set "TARGET_FILE=%SHARED_TARGET_PATH%\%%~nF%%~xF"
    copy "%%F" "!TARGET_FILE!" >nul 2>&1
    if errorlevel 1 (
        echo ❌ Erreur lors de la copie de %%~nF%%~xF
    ) else (
        echo ✅ Dépendance copiée: %%~nF%%~xF
    )
)

REM Copier les indicateurs
echo 📊 Copie des indicateurs...
for %%F in ("%INDICATORS_SOURCE_PATH%\*.mq5") do (
    set "TARGET_FILE=%INDICATORS_TARGET_PATH%\%%~nF%%~xF"
    copy "%%F" "!TARGET_FILE!" >nul 2>&1
    if errorlevel 1 (
        echo ❌ Erreur lors de la copie de %%~nF%%~xF
    ) else (
        echo ✅ Indicateur copié: %%~nF%%~xF
    )
)

REM Copier les EAs
echo 🤖 Copie des EAs...
for %%F in ("%EA_SOURCE_PATH%\*.mq5") do (
    set "TARGET_FILE=%EA_TARGET_PATH%\%%~nF%%~xF"
    copy "%%F" "!TARGET_FILE!" >nul 2>&1
    if errorlevel 1 (
        echo ❌ Erreur lors de la copie de %%~nF%%~xF
    ) else (
        echo ✅ EA copié: %%~nF%%~xF
    )
)

echo 🎉 Déploiement complet terminé avec succès!
echo ===============================================
echo 📁 Dépendances déployées: %SHARED_TARGET_PATH%
echo 📁 Indicateurs déployés: %INDICATORS_TARGET_PATH%
echo 📁 EAs déployés: %EA_TARGET_PATH%

pause
