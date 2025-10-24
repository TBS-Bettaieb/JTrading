#+------------------------------------------------------------------+
#|                                        Deploy_EA.ps1              |
#|                         RSI Divergence Trading System              |
#|                        Script de déploiement EA automatique       |
#+------------------------------------------------------------------+
#| Version: 1.0                                                     |
#| Usage: .\Deploy_EA.ps1 -EAName "RSI_Divergence_EA_Autonomous"    |
#+------------------------------------------------------------------+

param(
    [Parameter(Mandatory=$true)]
    [string]$EAName,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeDependencies = $true,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force = $false
)

# Configuration des chemins
$SourcePath = ".\EA\$EAName.mq5"
$TargetPath = "..\..\MQL5\Experts\$EAName.mq5"
$SharedSourcePath = ".\Shared"
$SharedTargetPath = "..\..\MQL5\Shared"

Write-Host "🚀 Déploiement de l'EA: $EAName" -ForegroundColor Green
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

# Copier l'EA principal
Write-Host "📋 Copie de l'EA principal..." -ForegroundColor Cyan
try {
    Copy-Item $SourcePath $TargetPath -Force
    Write-Host "✅ EA copié: $TargetPath" -ForegroundColor Green
} catch {
    Write-Host "❌ Erreur lors de la copie de l'EA: $($_.Exception.Message)" -ForegroundColor Red
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
Write-Host "📁 EA déployé: $TargetPath" -ForegroundColor White
if ($IncludeDependencies) {
    Write-Host "📁 Dépendances déployées: $SharedTargetPath" -ForegroundColor White
}
