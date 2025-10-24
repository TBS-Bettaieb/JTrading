@echo off
REM +------------------------------------------------------------------+
REM |                                    Deploy_Indicator.bat          |
REM |                         RSI Divergence Trading System              |
REM |                        Script de déploiement automatique          |
REM +------------------------------------------------------------------+
REM | Version: 1.0                                                     |
REM | Usage: Deploy_Indicator.bat "RSI_Divergence_Indicator_Modular"  |
REM +------------------------------------------------------------------+

setlocal enabledelayedexpansion

REM Vérifier les paramètres
if "%~1"=="" (
    echo ❌ Erreur: Nom de l'indicateur requis
    echo Usage: %0 ^<NomIndicateur^> [IncludeDependencies]
    echo Exemple: %0 "RSI_Divergence_Indicator_Modular" true
    exit /b 1
)

set "INDICATOR_NAME=%~1"
set "INCLUDE_DEPENDENCIES=%~2"

if "%INCLUDE_DEPENDENCIES%"=="" set "INCLUDE_DEPENDENCIES=true"

REM Configuration des chemins
set "SOURCE_PATH=.\Indicators\%INDICATOR_NAME%.mq5"
set "TARGET_PATH=..\..\MQL5\Indicators\%INDICATOR_NAME%.mq5"
set "SHARED_SOURCE_PATH=.\Shared"
set "SHARED_TARGET_PATH=..\..\MQL5\Shared"

echo 🚀 Déploiement de l'indicateur: %INDICATOR_NAME%
echo ===============================================

REM Vérifier que le fichier source existe
if not exist "%SOURCE_PATH%" (
    echo ❌ Erreur: Le fichier %SOURCE_PATH% n'existe pas!
    exit /b 1
)

REM Créer le dossier de destination s'il n'existe pas
for %%F in ("%TARGET_PATH%") do set "TARGET_DIR=%%~dpF"
if not exist "%TARGET_DIR%" (
    echo 📁 Création du dossier: %TARGET_DIR%
    mkdir "%TARGET_DIR%" 2>nul
)

REM Copier l'indicateur principal
echo 📋 Copie de l'indicateur principal...
copy "%SOURCE_PATH%" "%TARGET_PATH%" >nul 2>&1
if errorlevel 1 (
    echo ❌ Erreur lors de la copie de l'indicateur
    exit /b 1
) else (
    echo ✅ Indicateur copié: %TARGET_PATH%
)

REM Copier les dépendances si demandé
if /i "%INCLUDE_DEPENDENCIES%"=="true" (
    echo 📦 Copie des dépendances...
    
    REM Créer le dossier Shared s'il n'existe pas
    if not exist "%SHARED_TARGET_PATH%" (
        echo 📁 Création du dossier: %SHARED_TARGET_PATH%
        mkdir "%SHARED_TARGET_PATH%" 2>nul
    )
    
    REM Copier tous les fichiers MQH
    for %%F in ("%SHARED_SOURCE_PATH%\*.mqh") do (
        set "TARGET_FILE=%SHARED_TARGET_PATH%\%%~nF%%~xF"
        copy "%%F" "!TARGET_FILE!" >nul 2>&1
        if errorlevel 1 (
            echo ❌ Erreur lors de la copie de %%~nF%%~xF
        ) else (
            echo ✅ Dépendance copiée: %%~nF%%~xF
        )
    )
)

echo 🎉 Déploiement terminé avec succès!
echo ===============================================
echo 📁 Indicateur déployé: %TARGET_PATH%
if /i "%INCLUDE_DEPENDENCIES%"=="true" (
    echo 📁 Dépendances déployées: %SHARED_TARGET_PATH%
)

pause
