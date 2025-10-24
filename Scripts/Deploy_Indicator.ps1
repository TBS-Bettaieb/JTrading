#+------------------------------------------------------------------+
#|                                    Deploy_Indicator.ps1          |
#|                         RSI Divergence Trading System              |
#|                        Script de déploiement automatique          |
#+------------------------------------------------------------------+
#| Version: 1.0                                                     |
#| Usage: .\Deploy_Indicator.ps1 -IndicatorName "RSI_Divergence_Indicator_Modular" |
#+------------------------------------------------------------------+

param(
    [Parameter(Mandatory=$true)]
    [string]$IndicatorName,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeDependencies = $true,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force = $false
)

# Configuration des chemins
$SourcePath = ".\Indicators\$IndicatorName.mq5"
$TargetPath = "..\..\MQL5\Indicators\$IndicatorName.mq5"
$SharedSourcePath = ".\Shared"
$SharedTargetPath = "..\..\MQL5\Shared"

Write-Host "🚀 Déploiement de l'indicateur: $IndicatorName" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

# Vérifier que le fichier source existe
if (-not (Test-Path $SourcePath)) {
    Write-Host "❌ Erreur: Le fichier $SourcePath n'existe pas!" -ForegroundColor Red
    exit 1
}

# Créer le dossier de destination s'il n'existe pas
$TargetDir = Split-Path $TargetPath -Parent
if (-not (Test-Path $TargetDir)) {
    Write-Host "📁 Création du dossier: $TargetDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}

# Copier l'indicateur principal
Write-Host "📋 Copie de l'indicateur principal..." -ForegroundColor Cyan
try {
    Copy-Item $SourcePath $TargetPath -Force
    Write-Host "✅ Indicateur copié: $TargetPath" -ForegroundColor Green
} catch {
    Write-Host "❌ Erreur lors de la copie de l'indicateur: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Copier les dépendances si demandé
if ($IncludeDependencies) {
    Write-Host "📦 Copie des dépendances..." -ForegroundColor Cyan
    
    # Créer le dossier Shared s'il n'existe pas
    if (-not (Test-Path $SharedTargetPath)) {
        Write-Host "📁 Création du dossier: $SharedTargetPath" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $SharedTargetPath -Force | Out-Null
    }
    
    # Copier tous les fichiers MQH
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
}

Write-Host "🎉 Déploiement terminé avec succès!" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host "📁 Indicateur déployé: $TargetPath" -ForegroundColor White
if ($IncludeDependencies) {
    Write-Host "📁 Dépendances déployées: $SharedTargetPath" -ForegroundColor White
}
