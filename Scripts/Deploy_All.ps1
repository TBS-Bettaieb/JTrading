#+------------------------------------------------------------------+
#|                                        Deploy_All.ps1              |
#|                         RSI Divergence Trading System              |
#|                        Script de déploiement complet              |
#+------------------------------------------------------------------+
#| Version: 1.0                                                     |
#| Usage: .\Deploy_All.ps1                                          |
#+------------------------------------------------------------------+

param(
    [Parameter(Mandatory=$false)]
    [switch]$Force = $false
)

Write-Host "🚀 Déploiement complet du système RSI Divergence" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

# Configuration des chemins
$SharedSourcePath = ".\Shared"
$SharedTargetPath = "..\..\MQL5\Shared"
$IndicatorsSourcePath = ".\Indicators"
$IndicatorsTargetPath = "..\..\MQL5\Indicators"
$EASourcePath = ".\EA"
$EATargetPath = "..\..\MQL5\Experts"

# Créer les dossiers de destination s'ils n'existent pas
$Directories = @($SharedTargetPath, $IndicatorsTargetPath, $EATargetPath)
foreach ($dir in $Directories) {
    if (-not (Test-Path $dir)) {
        Write-Host "📁 Création du dossier: $dir" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# Copier les dépendances partagées
Write-Host "📦 Copie des dépendances partagées..." -ForegroundColor Cyan
$MqhFiles = Get-ChildItem -Path $SharedSourcePath -Filter "*.mqh"
foreach ($file in $MqhFiles) {
    $TargetFile = Join-Path $SharedTargetPath $file.Name
    try {
        Copy-Item $file.FullName $TargetFile -Force
        Write-Host "✅ Dépendance copiée: $($file.Name)" -ForegroundColor Green
    } catch {
        Write-Host "❌ Erreur lors de la copie de $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Copier les indicateurs
Write-Host "📊 Copie des indicateurs..." -ForegroundColor Cyan
$IndicatorFiles = Get-ChildItem -Path $IndicatorsSourcePath -Filter "*.mq5"
foreach ($file in $IndicatorFiles) {
    $TargetFile = Join-Path $IndicatorsTargetPath $file.Name
    try {
        Copy-Item $file.FullName $TargetFile -Force
        Write-Host "✅ Indicateur copié: $($file.Name)" -ForegroundColor Green
    } catch {
        Write-Host "❌ Erreur lors de la copie de $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Copier les EAs
Write-Host "🤖 Copie des EAs..." -ForegroundColor Cyan
$EAFiles = Get-ChildItem -Path $EASourcePath -Filter "*.mq5"
foreach ($file in $EAFiles) {
    $TargetFile = Join-Path $EATargetPath $file.Name
    try {
        Copy-Item $file.FullName $TargetFile -Force
        Write-Host "✅ EA copié: $($file.Name)" -ForegroundColor Green
    } catch {
        Write-Host "❌ Erreur lors de la copie de $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "🎉 Déploiement complet terminé avec succès!" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host "📁 Dépendances déployées: $SharedTargetPath" -ForegroundColor White
Write-Host "📁 Indicateurs déployés: $IndicatorsTargetPath" -ForegroundColor White
Write-Host "📁 EAs déployés: $EATargetPath" -ForegroundColor White
