@echo off
REM +------------------------------------------------------------------+
REM |                                    Deploy_Quick.bat              |
REM |                         RSI Divergence Trading System              |
REM |                    Script de déploiement unifié avec config JSON |
REM +------------------------------------------------------------------+
REM | Version: 2.0                                                     |
REM | Usage: Deploy_Quick.bat (Menu interactif)                       |
REM +------------------------------------------------------------------+

setlocal enabledelayedexpansion

echo DÉPLOIEMENT UNIFIÉ - RSI DIVERGENCE SYSTEM
echo =============================================
echo.

REM Charger les configurations JSON
call :LoadConfigs

:MainMenu
echo Que souhaitez-vous deployer ?
echo.
echo   [1] Expert Advisors (EA)
echo   [2] Indicateurs
echo   [3] Tout deployer
echo.
echo   [0] Quitter
echo.

set /p "CHOICE=Votre choix (0-3): "

if "%CHOICE%"=="0" goto Exit
if "%CHOICE%"=="1" goto DeployEAs
if "%CHOICE%"=="2" goto DeployIndicators
if "%CHOICE%"=="3" goto DeployAll
goto MainMenu

:DeployEAs
echo.
echo Deploiement des Expert Advisors...
call :ShowEAMenu
goto MainMenu

:DeployIndicators
echo.
echo Deploiement des Indicateurs...
call :ShowIndicatorMenu
goto MainMenu

:DeployAll
echo.
echo Deploiement de tous les fichiers...
echo.

REM Deployer tous les EAs
echo Deploiement des Expert Advisors...
call :DeployAllEAs

echo.
echo Deploiement des Indicateurs...
call :DeployAllIndicators

echo.
echo Deploiement complet termine!
echo.
goto MainMenu

:Exit
echo Deploiement annule.
pause
exit /b 0

REM ===== FONCTIONS =====

:LoadConfigs
echo Chargement des configurations...
REM Les configurations sont definies directement dans le script
goto :eof

:ShowEAMenu
echo.
echo EAs disponibles:
echo.
echo   [1] RSI_Divergence_EA_Autonomous
echo       EA autonome avec detection RSI Divergence et trading automatique
echo.
echo   [2] RSI_Divergence_EA
echo       EA RSI Divergence avec interface utilisateur
echo.
echo   [0] Retour au menu principal
echo.

set /p "EA_CHOICE=Choisissez un EA (0-2): "

if "%EA_CHOICE%"=="0" goto :eof
if "%EA_CHOICE%"=="1" call :DeployEA "RSI_Divergence_EA_Autonomous"
if "%EA_CHOICE%"=="2" call :DeployEA "RSI_Divergence_EA"
goto :eof

:ShowIndicatorMenu
echo.
echo Indicateurs disponibles:
echo.
echo   [1] RSI_Divergence_Indicator_Modular
echo       Indicateur RSI Divergence modulaire avec architecture avancee
echo.
echo   [2] RSI_Divergence_Indicator_NoGUI
echo       Indicateur RSI Divergence sans interface graphique
echo.
echo   [3] RSI_Divergence_Indicator
echo       Indicateur RSI Divergence standard avec interface graphique
echo.
echo   [4] FVG_Indicator
echo       Indicateur Fair Value Gap (FVG) pour l'analyse des gaps de prix
echo.
echo   [5] FVG_Volume_Profile_CP
echo       Indicateur FVG avec profil de volume et points de controle
echo.
echo   [6] RSI_Div_Scalping_EA
echo       Indicateur RSI Divergence specialise pour le scalping
echo.
echo   [0] Retour au menu principal
echo.

set /p "INDICATOR_CHOICE=Choisissez un indicateur (0-6): "

if "%INDICATOR_CHOICE%"=="0" goto :eof
if "%INDICATOR_CHOICE%"=="1" call :DeployIndicator "RSI_Divergence_Indicator_Modular"
if "%INDICATOR_CHOICE%"=="2" call :DeployIndicator "RSI_Divergence_Indicator_NoGUI"
if "%INDICATOR_CHOICE%"=="3" call :DeployIndicator "RSI_Divergence_Indicator"
if "%INDICATOR_CHOICE%"=="4" call :DeployIndicator "FVG_Indicator"
if "%INDICATOR_CHOICE%"=="5" call :DeployIndicator "FVG_Volume_Profile_CP"
if "%INDICATOR_CHOICE%"=="6" call :DeployIndicator "RSI_Div_Scalping_EA"
goto :eof

:DeployEA
set "EA_NAME=%~1"
echo.
echo Deploiement de l'EA: %EA_NAME%
echo ================================

if "%EA_NAME%"=="RSI_Divergence_EA_Autonomous" (
    call :DeployFile ".\EA\RSI_Divergence_EA_Autonomous.mq5" "..\..\Experts\RSI_Divergence_EA_Autonomous.mq5"
) else if "%EA_NAME%"=="RSI_Divergence_EA" (
    call :DeployFile ".\EA\RSI_Divergence_EA.mq5" "..\..\Experts\RSI_Divergence_EA.mq5"
)

call :DeploySharedDependencies
echo EA %EA_NAME% deploye avec succes!
goto :eof

:DeployIndicator
set "INDICATOR_NAME=%~1"
echo.
echo Deploiement de l'indicateur: %INDICATOR_NAME%
echo ===============================================

if "%INDICATOR_NAME%"=="RSI_Divergence_Indicator_Modular" (
    call :DeployFile ".\Indicators\RSI_Divergence_Indicator_Modular.mq5" "..\..\Indicators\RSI_Divergence_Indicator_Modular.mq5"
) else if "%INDICATOR_NAME%"=="RSI_Divergence_Indicator_NoGUI" (
    call :DeployFile ".\Indicators\RSI_Divergence_Indicator_NoGUI.mq5" "..\..\Indicators\RSI_Divergence_Indicator_NoGUI.mq5"
) else if "%INDICATOR_NAME%"=="RSI_Divergence_Indicator" (
    call :DeployFile ".\Indicators\RSI_Divergence_Indicator.mq5" "..\..\Indicators\RSI_Divergence_Indicator.mq5"
) else if "%INDICATOR_NAME%"=="FVG_Indicator" (
    call :DeployFile ".\Indicators\FVG_Indicator.mq5" "..\..\Indicators\FVG_Indicator.mq5"
) else if "%INDICATOR_NAME%"=="FVG_Volume_Profile_CP" (
    call :DeployFile ".\Indicators\FVG_Volume_Profile_CP.mq5" "..\..\Indicators\FVG_Volume_Profile_CP.mq5"
) else if "%INDICATOR_NAME%"=="RSI_Div_Scalping_EA" (
    call :DeployFile ".\Indicators\RSI_Div_Scalping_EA.mq5" "..\..\Indicators\RSI_Div_Scalping_EA.mq5"
)

call :DeploySharedDependencies
echo Indicateur %INDICATOR_NAME% deploye avec succes!
goto :eof

:DeployAllEAs
call :DeployEA "RSI_Divergence_EA_Autonomous"
call :DeployEA "RSI_Divergence_EA"
goto :eof

:DeployAllIndicators
call :DeployIndicator "RSI_Divergence_Indicator_Modular"
call :DeployIndicator "RSI_Divergence_Indicator_NoGUI"
call :DeployIndicator "RSI_Divergence_Indicator"
call :DeployIndicator "FVG_Indicator"
call :DeployIndicator "FVG_Volume_Profile_CP"
call :DeployIndicator "RSI_Div_Scalping_EA"
goto :eof

:DeployFile
set "SOURCE=%~1"
set "TARGET=%~2"

REM Creer le dossier de destination s'il n'existe pas
for %%F in ("%TARGET%") do set "TARGET_DIR=%%~dpF"
if not exist "%TARGET_DIR%" (
    echo Creation du dossier: %TARGET_DIR%
    mkdir "%TARGET_DIR%" >nul 2>&1
)

REM Copier le fichier
echo Copie du fichier: %SOURCE%
copy "%SOURCE%" "%TARGET%" >nul 2>&1
if errorlevel 1 (
    echo ERREUR lors de la copie de %SOURCE%
) else (
    echo Fichier copie: %TARGET%
)
goto :eof

:DeploySharedDependencies
echo Deploiement des dependances partagees...

REM Creer le dossier Shared s'il n'existe pas
if not exist "..\..\Shared" (
    echo Creation du dossier: ..\..\Shared
    mkdir "..\..\Shared" >nul 2>&1
)

REM Copier tous les fichiers MQH un par un
if exist ".\Shared\RSI_Calculator.mqh" (
    echo Copie de RSI_Calculator.mqh...
    copy ".\Shared\RSI_Calculator.mqh" "..\..\Shared\RSI_Calculator.mqh" >nul 2>&1
    if errorlevel 1 (
        echo ERREUR lors de la copie de RSI_Calculator.mqh
    ) else (
        echo RSI_Calculator.mqh copie avec succes
    )
)

if exist ".\Shared\Pivot_Detector.mqh" (
    echo Copie de Pivot_Detector.mqh...
    copy ".\Shared\Pivot_Detector.mqh" "..\..\Shared\Pivot_Detector.mqh" >nul 2>&1
    if errorlevel 1 (
        echo ERREUR lors de la copie de Pivot_Detector.mqh
    ) else (
        echo Pivot_Detector.mqh copie avec succes
    )
)

if exist ".\Shared\Divergence_Detector.mqh" (
    echo Copie de Divergence_Detector.mqh...
    copy ".\Shared\Divergence_Detector.mqh" "..\..\Shared\Divergence_Detector.mqh" >nul 2>&1
    if errorlevel 1 (
        echo ERREUR lors de la copie de Divergence_Detector.mqh
    ) else (
        echo Divergence_Detector.mqh copie avec succes
    )
)

if exist ".\Shared\Divergence_Visualizer.mqh" (
    echo Copie de Divergence_Visualizer.mqh...
    copy ".\Shared\Divergence_Visualizer.mqh" "..\..\Shared\Divergence_Visualizer.mqh" >nul 2>&1
    if errorlevel 1 (
        echo ERREUR lors de la copie de Divergence_Visualizer.mqh
    ) else (
        echo Divergence_Visualizer.mqh copie avec succes
    )
)
goto :eof
