#Requires -Version 5.1

<#
.SYNOPSIS
    Script de deploiement automatique pour MetaTrader 5

.DESCRIPTION
    Ce script detecte automatiquement les installations MetaTrader 5 et deploie
    les Expert Advisors, indicateurs et fichiers partages vers les dossiers MQL5 appropries.

.PARAMETER Type
    Type de fichiers a deployer: EA, Indicators, Shared, ou All

.PARAMETER TargetPath
    Chemin specifique vers une installation MT5

.PARAMETER AllInstallations
    Deployer vers toutes les installations detectees

.PARAMETER CreateBackup
    Creer une sauvegarde des fichiers existants

.PARAMETER Silent
    Mode silencieux sans interaction utilisateur

.PARAMETER NoSubfolder
    Ne pas créer de sous-dossier pour les EA (les mettre directement dans Experts/)

.PARAMETER CompileAfterDeploy
    Compiler automatiquement les fichiers .mq5 vers .ex5 après déploiement

.EXAMPLE
    .\Deploy-MT5-Fixed.ps1 -Type All -AllInstallations
    Deploie tous les fichiers vers toutes les installations MT5 detectees

.EXAMPLE
    .\Deploy-MT5-Fixed.ps1 -Type EA -TargetPath "C:\Program Files\MetaTrader 5"
    Deploie uniquement les Expert Advisors vers une installation specifique

.EXAMPLE
    .\Deploy-MT5-Fixed.ps1 -Type All -AllInstallations -CompileAfterDeploy
    Deploie tous les fichiers et les compile automatiquement vers .ex5
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('EA', 'Indicators', 'Shared', 'All')]
    [string]$Type = 'All',
    
    [Parameter()]
    [string]$TargetPath,
    
    [Parameter()]
    [switch]$AllInstallations,
    
    [Parameter()]
    [switch]$CreateBackup,
    
    [Parameter()]
    [switch]$Silent,
    
    [Parameter()]
    [switch]$NoSubfolder,
    
    [Parameter()]
    [switch]$CompileAfterDeploy
)

# Configuration globale
$Script:ProjectRoot = $PSScriptRoot

# ✅ NOUVEAU: État du déploiement pour le récapitulatif
$Script:DeployState = @{
    InstallationCount = 0
    FileCount = @{
        EA = 0
        Indicators = 0
        Shared = 0
    }
    CompileResults = @{
        Success = 0
        Failed = 0
        Total = 0
    }
}

$Script:Config = @{
    SourcePaths = @{
        'EA' = 'EA'
        'Indicators' = 'Indicators'
        'Shared' = 'Shared'
    }
    TargetSubdirs = @{
        # ✅ CORRECTION: Créer sous-dossier EA sous Experts (sauf si -NoSubfolder)
        'EA' = if ($NoSubfolder) { 'Experts' } else { 'Experts\EA' }
        'Indicators' = 'Indicators'
        'Shared' = 'Shared'
    }
    FileExtensions = @{
        'EA' = '*.mq5'
        'Indicators' = '*.mq5'
        'Shared' = '*.mqh'
    }
}

#region Helper Functions
function Get-MenuChoice {
    <#
    .SYNOPSIS
        Obtient un choix utilisateur avec sélection one-key (sans Entrée)
    
    .PARAMETER Prompt
        Message à afficher avant la saisie
    
    .PARAMETER ValidChoices
        Tableau des choix valides (ex: @('0','1','2','3','4'))
    
    .PARAMETER AllowEscape
        Permet ESC pour annuler (retourne $null)
    
    .EXAMPLE
        $choice = Get-MenuChoice -Prompt "Votre choix (0-4):" -ValidChoices @('0','1','2','3','4')
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,
        
        [Parameter(Mandatory)]
        [string[]]$ValidChoices,
        
        [Parameter()]
        [switch]$AllowEscape
    )
    
    Write-Host ""
    Write-Host $Prompt -NoNewline -ForegroundColor Yellow
    Write-Host " " -NoNewline
    
    do {
        try {
            # Tentative avec ReadKey pour one-key choice
            $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            $choice = $key.Character.ToString()
            
            # Gérer ESC si autorisé
            if ($AllowEscape -and $key.VirtualKeyCode -eq 27) {
                Write-Host "[Annulé]" -ForegroundColor Red
                return $null
            }
            
            # Vérifier si choix valide
            if ($choice -in $ValidChoices) {
                Write-Host $choice -ForegroundColor Green
                return $choice
            }
            else {
                # Choix invalide: bip sonore
                [Console]::Beep(800, 100)
            }
        }
        catch {
            # Fallback vers Read-Host si ReadKey ne fonctionne pas (ISE, certains terminaux)
            Write-Host ""
            Write-ColorOutput "Mode ReadKey non supporté, utilisation de Read-Host" -Level Warning
            
            $choice = Read-Host "Entrez votre choix"
            if ($choice -in $ValidChoices) {
                return $choice
            }
            elseif ($AllowEscape -and $choice -eq '') {
                return $null
            }
            else {
                Write-ColorOutput "Choix invalide. Valeurs acceptées: $($ValidChoices -join ', ')" -Level Error
            }
        }
    } while ($true)
}

function Write-ColorOutput {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $colors = @{
        'Info' = 'White'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error' = 'Red'
    }
    
    Write-Host $Message -ForegroundColor $colors[$Level]
}

function Show-Header {
    <#
    .SYNOPSIS
        Affiche l'en-tête du script avec récapitulatif de l'état actuel
    
    .PARAMETER State
        Hashtable contenant l'état actuel du déploiement
    
    .PARAMETER CurrentStep
        Nom de l'étape actuelle
    
    .EXAMPLE
        Show-Header -State $deployState -CurrentStep "Sélection du type"
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [hashtable]$State = @{},
        
        [Parameter()]
        [string]$CurrentStep = "Initialisation"
    )
    
    # Nettoyer la console
    Clear-Host
    
    # Largeur de l'en-tête (adapter selon vos besoins)
    $width = 70
    $topBorder = "+" + ("=" * ($width - 2)) + "+"
    $bottomBorder = "+" + ("=" * ($width - 2)) + "+"
    $separator = "|" + ("-" * ($width - 2)) + "|"
    
    # Fonction helper pour centrer le texte
    function Format-CenteredText {
        param([string]$Text, [int]$Width)
        $padding = $Width - $Text.Length - 2
        $leftPad = [Math]::Floor($padding / 2)
        $rightPad = $padding - $leftPad
        return "|" + (" " * $leftPad) + $Text + (" " * $rightPad) + "|"
    }
    
    # Fonction helper pour texte aligné à gauche
    function Format-LeftText {
        param([string]$Text, [int]$Width)
        $padding = $Width - $Text.Length - 3
        return "| " + $Text + (" " * $padding) + "|"
    }
    
    # Afficher l'en-tête
    Write-Host $topBorder -ForegroundColor Cyan
    Write-Host (Format-CenteredText "DÉPLOIEMENT MT5 - RSI DIVERGENCE" $width) -ForegroundColor Cyan
    Write-Host $separator -ForegroundColor Cyan
    
    # Informations système
    if ($State.ContainsKey('InstallationCount')) {
        $instText = "[*] Installations detectees : $($State.InstallationCount)"
        Write-Host (Format-LeftText $instText $width) -ForegroundColor White
    }
    
    if ($State.ContainsKey('FileCount')) {
        $fc = $State.FileCount
        $filesText = "[*] Fichiers disponibles    : EA ($($fc.EA)) | Indicators ($($fc.Indicators)) | Shared ($($fc.Shared))"
        Write-Host (Format-LeftText $filesText $width) -ForegroundColor White
    }
    
    # Séparateur si des choix ont été faits
    if ($State.Count -gt 2) {
        Write-Host $separator -ForegroundColor Cyan
    }
    
    # Choix effectués (afficher en vert avec checkmark)
    if ($State.ContainsKey('SelectedType')) {
        $typeText = "[OK] Type selectionne         : $($State.SelectedType)"
        Write-Host (Format-LeftText $typeText $width) -ForegroundColor Green
    }
    
    if ($State.ContainsKey('SelectedInstallations')) {
        $instText = "[OK] Installations cibles     : $($State.SelectedInstallations)"
        Write-Host (Format-LeftText $instText $width) -ForegroundColor Green
    }
    
    if ($State.ContainsKey('CreateBackup')) {
        $backupText = "[OK] Sauvegardes              : $($State.CreateBackup)"
        Write-Host (Format-LeftText $backupText $width) -ForegroundColor Green
    }
    
    # Étape actuelle
    Write-Host $separator -ForegroundColor Cyan
    $stepIcon = if ($State.ContainsKey('Deploying')) { "[>>]" } else { "[..]" }
    $stepText = "$stepIcon Etape actuelle          : $CurrentStep"
    Write-Host (Format-LeftText $stepText $width) -ForegroundColor Yellow
    
    Write-Host $bottomBorder -ForegroundColor Cyan
    Write-Host ""
}

function Get-FileDependencies {
    <#
    .SYNOPSIS
        Analyse un fichier MQ5/MQ4 pour extraire ses dépendances #include
    
    .PARAMETER FilePath
        Chemin complet vers le fichier à analyser
    
    .PARAMETER SourceRoot
        Dossier racine du projet pour résoudre les chemins relatifs
    
    .OUTPUTS
        Tableau de chemins complets vers les fichiers .mqh dépendants
    
    .EXAMPLE
        $deps = Get-FileDependencies -FilePath "EA\MyEA.mq5" -SourceRoot $PSScriptRoot
        # Retourne: @("C:\Project\Shared\RSI_Calculator.mqh", "C:\Project\Shared\Pivot_Detector.mqh")
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        
        [Parameter(Mandatory)]
        [string]$SourceRoot
    )
    
    $dependencies = [System.Collections.ArrayList]::new()
    
    if (-not (Test-Path $FilePath)) {
        Write-Verbose "Fichier introuvable: $FilePath"
        return @()
    }
    
    try {
        # Lire le contenu du fichier
        $content = Get-Content -Path $FilePath -Encoding UTF8
        
        # Patterns à détecter:
        # #include <Shared\RSI_Calculator.mqh>
        # #include "Shared\Pivot_Detector.mqh"
        # #include "..\Shared\Divergence_Detector.mqh"
        
        $includePattern = '#include\s+[<"]([^>"]+\.mqh)[>"]'
        
        foreach ($line in $content) {
            if ($line -match $includePattern) {
                $includePath = $Matches[1]
                
                # Nettoyer le chemin (supprimer espaces, normaliser séparateurs)
                $includePath = $includePath.Trim() -replace '/', '\'
                
                # Résoudre le chemin complet
                # Cas 1: Chemin absolu depuis SourceRoot (ex: "Shared\File.mqh")
                $fullPath = Join-Path $SourceRoot $includePath
                
                # Cas 2: Chemin relatif (ex: "..\Shared\File.mqh")
                if ($includePath -match '^\.\.' -or $includePath -match '^\.\') {
                    $fileDir = Split-Path $FilePath -Parent
                    $fullPath = Join-Path $fileDir $includePath
                    $fullPath = [System.IO.Path]::GetFullPath($fullPath)
                }
                
                # Vérifier que le fichier existe
                if (Test-Path $fullPath) {
                    if ($dependencies -notcontains $fullPath) {
                        [void]$dependencies.Add($fullPath)
                        Write-Verbose "  Dépendance trouvée: $includePath"
                    }
                }
                else {
                    Write-Verbose "  Dépendance introuvable: $includePath (résolu en $fullPath)"
                }
            }
        }
        
        return $dependencies.ToArray()
    }
    catch {
        Write-Warning "Erreur lors de l'analyse de $FilePath : $($_.Exception.Message)"
        return @()
    }
}

function Compile-MQ5Files {
    <#
    .SYNOPSIS
        Compile des fichiers MQ5 vers EX5 en utilisant MetaEditor
    
    .DESCRIPTION
        Utilise metaeditor64.exe pour compiler les fichiers .mq5 vers .ex5.
        Gère les erreurs et affiche les résultats de compilation.
    
    .PARAMETER MT5Path
        Chemin de l'installation MT5
    
    .PARAMETER FilesToCompile
        Tableau de chemins complets vers les fichiers .mq5 à compiler
    
    .PARAMETER ShowOutput
        Afficher les logs de compilation détaillés
    
    .OUTPUTS
        Hashtable avec Success/Failed count
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$MT5Path,
        
        [Parameter(Mandatory)]
        [string[]]$FilesToCompile,
        
        [Parameter()]
        [switch]$ShowOutput
    )
    
    $results = @{ Success = 0; Failed = 0; Total = $FilesToCompile.Count }
    
    if ($FilesToCompile.Count -eq 0) {
        Write-Verbose "Aucun fichier à compiler"
        return $results
    }
    
    # Chercher metaeditor64.exe ou metaeditor.exe
    $metaEditorPaths = @(
        Join-Path $MT5Path "metaeditor64.exe",
        Join-Path $MT5Path "metaeditor.exe"
    )
    
    $metaEditorExe = $null
    foreach ($path in $metaEditorPaths) {
        if (Test-Path $path) {
            $metaEditorExe = $path
            break
        }
    }
    
    if (-not $metaEditorExe) {
        Write-Warning "MetaEditor introuvable dans $MT5Path. Compilation ignorée."
        Write-Verbose "Chemins recherchés: $($metaEditorPaths -join ', ')"
        return $results
    }
    
    Write-Verbose "MetaEditor trouvé: $metaEditorExe"
    
    # Compiler chaque fichier
    foreach ($filePath in $FilesToCompile) {
        if (-not (Test-Path $filePath)) {
            Write-Warning "Fichier introuvable: $filePath"
            $results.Failed++
            continue
        }
        
        $fileName = Split-Path $filePath -Leaf
        $fileDir = Split-Path $filePath -Parent
        
        try {
            Write-Verbose "Compilation de $fileName..."
            
            # Construire la commande de compilation
            $compileArgs = @(
                "/compile:`"$filePath`"",
                "/log"
            )
            
            # Lancer la compilation avec timeout
            $process = Start-Process -FilePath $metaEditorExe -ArgumentList $compileArgs -WorkingDirectory $fileDir -Wait -PassThru -NoNewWindow
            
            # Vérifier le code de sortie
            if ($process.ExitCode -eq 0) {
                # Vérifier qu'un fichier .ex5 a été créé
                $ex5Path = $filePath -replace '\.mq5$', '.ex5'
                if (Test-Path $ex5Path) {
                    Write-Verbose "  [OK] $fileName compilé avec succès"
                    $results.Success++
                } else {
                    Write-Warning "  [!] $fileName : compilation réussie mais fichier .ex5 introuvable"
                    $results.Failed++
                }
            } else {
                Write-Warning "  [X] $fileName : échec de compilation (code: $($process.ExitCode))"
                $results.Failed++
            }
            
            # Afficher les logs si demandé
            if ($ShowOutput -and $process.StandardOutput) {
                $output = $process.StandardOutput.ReadToEnd()
                if ($output) {
                    Write-Host "Logs de compilation pour $fileName :" -ForegroundColor Cyan
                    Write-Host $output -ForegroundColor Gray
                }
            }
        }
        catch {
            Write-Warning "Erreur lors de la compilation de $fileName : $($_.Exception.Message)"
            $results.Failed++
        }
    }
    
    return $results
}

function Find-MT5Installations {
    Write-ColorOutput "Recherche des installations MetaTrader 5..." -Level Info
    
    $installations = [System.Collections.ArrayList]::new()
    $searchPaths = @(
        "C:\Program Files\*MetaTrader*"
        "C:\Program Files (x86)\*MetaTrader*"
        "$env:APPDATA\MetaQuotes\Terminal\*"
    )
    
    foreach ($searchPath in $searchPaths) {
        try {
            $paths = Get-ChildItem -Path $searchPath -Directory -ErrorAction SilentlyContinue
            foreach ($path in $paths) {
                $mql5Path = Join-Path $path.FullName "MQL5"
                if (Test-Path $mql5Path) {
                    $installations.Add([PSCustomObject]@{
                        Name = $path.Name
                        Path = $path.FullName
                        MQL5Path = $mql5Path
                    }) | Out-Null
                }
            }
        }
        catch {
            Write-Verbose "Erreur lors de la recherche dans $searchPath : $($_.Exception.Message)"
        }
    }
    
    Write-ColorOutput "+ $($installations.Count) installation(s) MT5 detectee(s)" -Level Success
    return $installations.ToArray()
}

function Get-SourceFiles {
    Write-Host ""
    Write-Host "Validation des fichiers sources..." -ForegroundColor Yellow
    
    $sourceData = @{}
    
    foreach ($type in $Script:Config.SourcePaths.Keys) {
        $sourcePath = $Script:Config.SourcePaths[$type]
        $extension = $Script:Config.FileExtensions[$type]
        
        if (Test-Path $sourcePath) {
            # ✅ CORRECTION: Utiliser -Include au lieu de -Filter pour supporter -Recurse
            $files = Get-ChildItem -Path $sourcePath -Include $extension -File -Recurse
            
            $sourceData[$type] = @{
                Path = $sourcePath
                Files = $files
                Count = $files.Count
            }
            
            if ($files.Count -gt 0) {
                Write-ColorOutput "  + $type : $($files.Count) fichier(s)" -Level Success
                
                # Afficher les fichiers trouvés en mode verbose
                foreach ($file in $files) {
                    Write-Verbose "    - $($file.Name)"
                }
            } else {
                Write-ColorOutput "  ! $type : Aucun fichier trouve" -Level Warning
            }
        }
        else {
            Write-ColorOutput "  - $type : Dossier introuvable ($sourcePath)" -Level Error
            $sourceData[$type] = @{
                Path = $sourcePath
                Files = @()
                Count = 0
            }
        }
    }
    
    return $sourceData
}

function Deploy-SingleFile {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$SourceFile,
        
        [Parameter(Mandatory)]
        [string]$TargetFile,
        
        [Parameter()]
        [switch]$CreateBackup
    )
    
    try {
        if (-not (Test-Path $SourceFile)) {
            Write-Host "       [X] Source introuvable: $SourceFile" -ForegroundColor Red
            return $false
        }
        
        $targetDir = Split-Path $TargetFile -Parent
        if (-not (Test-Path $targetDir)) {
            New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
            Write-Verbose "       [DIR] Dossier cree: $targetDir"
        }
        
        if ($CreateBackup -and (Test-Path $TargetFile)) {
            $backupFile = "{0}.backup.{1}" -f $TargetFile, (Get-Date -Format 'yyyyMMddHHmmss')
            Copy-Item -Path $TargetFile -Destination $backupFile -Force
            Write-Verbose "       [BAK] Backup cree: $backupFile"
        }
        
        Copy-Item -Path $SourceFile -Destination $TargetFile -Force
        
        $fileName = Split-Path $SourceFile -Leaf
        Write-Host ("       [OK] {0}" -f $fileName) -ForegroundColor Green
        
        return $true
    }
    catch {
        $fileName = Split-Path $SourceFile -Leaf
        Write-Host ("       [X] {0} : {1}" -f $fileName, $_.Exception.Message) -ForegroundColor Red
        return $false
    }
}

function Deploy-FilesByType {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('EA', 'Indicators', 'Shared')]
        [string]$Type,
        
        [Parameter(Mandatory)]
        [array]$Installations,
        
        [Parameter(Mandatory)]
        [hashtable]$SourceInfo,
        
        [Parameter()]
        [switch]$CreateBackup,
        
        [Parameter()]
        [switch]$CompileAfterDeploy
    )
    
    # ✅ NOUVEAU: Afficher section de déploiement claire
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host ("        DEPLOIEMENT : {0,-28} " -f $Type.ToUpper()) -ForegroundColor Cyan
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host ""
    
    if ($SourceInfo.Count -eq 0) {
        Write-Host "  [!] Aucun fichier a deployer" -ForegroundColor Yellow
        return @{ Success = 0; Failed = 0 }
    }
    
    $results = @{ Success = 0; Failed = 0 }
    $targetSubdir = $Script:Config.TargetSubdirs[$Type]
    
    foreach ($installation in $Installations) {
        Write-Host ""
        Write-Host "  [*] Installation : $($installation.Name)" -ForegroundColor Yellow
        Write-Host ("     [DIR] Cible    : $($installation.MQL5Path)\$targetSubdir") -ForegroundColor DarkGray
        Write-Host ""
        
        foreach ($file in $SourceInfo.Files) {
            $targetPath = Join-Path $installation.MQL5Path $targetSubdir
            $targetFile = Join-Path $targetPath $file.Name
            
            # Déployer le fichier principal
            if (Deploy-SingleFile -SourceFile $file.FullName -TargetFile $targetFile -CreateBackup:$CreateBackup) {
                $results.Success++
                
                # Si c'est un EA, copier ses dépendances
                if ($Type -eq 'EA' -and $file.Extension -eq '.mq5') {
                    $dependencies = Get-FileDependencies -FilePath $file.FullName -SourceRoot $Script:ProjectRoot
                    
                    if ($dependencies.Count -gt 0) {
                        Write-Host ("       [DEP] Dependances : {0} fichier(s)" -f $dependencies.Count) -ForegroundColor Cyan
                        
                        foreach ($depFile in $dependencies) {
                            $depFileName = Split-Path $depFile -Leaf
                            $depTargetFile = Join-Path $targetPath $depFileName
                            
                            if (Deploy-SingleFile -SourceFile $depFile -TargetFile $depTargetFile -CreateBackup:$CreateBackup) {
                                Write-Verbose "       [OK] $depFileName"
                            }
                            else {
                                Write-Warning "       [X] $depFileName"
                            }
                        }
                    }
                }
            }
            else {
                $results.Failed++
            }
        }
    }
    
    # ✅ NOUVEAU: Compilation des fichiers .mq5 si demandée
    if ($CompileAfterDeploy -and $Type -in @('EA', 'Indicators') -and $results.Success -gt 0) {
        Write-Host ""
        Write-Host "================================================" -ForegroundColor Yellow
        Write-Host ("        COMPILATION : {0,-28} " -f $Type.ToUpper()) -ForegroundColor Yellow
        Write-Host "================================================" -ForegroundColor Yellow
        
        $totalCompileResults = @{ Success = 0; Failed = 0; Total = 0 }
        
        foreach ($installation in $Installations) {
            Write-Host ""
            Write-Host "  [*] Installation : $($installation.Name)" -ForegroundColor Yellow
            
            # Collecter les fichiers .mq5 déployés pour cette installation
            $filesToCompile = @()
            $targetSubdir = $Script:Config.TargetSubdirs[$Type]
            $targetPath = Join-Path $installation.MQL5Path $targetSubdir
            
            foreach ($file in $SourceInfo.Files) {
                if ($file.Extension -eq '.mq5') {
                    $deployedFile = Join-Path $targetPath $file.Name
                    if (Test-Path $deployedFile) {
                        $filesToCompile += $deployedFile
                    }
                }
            }
            
            if ($filesToCompile.Count -gt 0) {
                Write-Host ("     [COMP] Compilation de {0} fichier(s) .mq5" -f $filesToCompile.Count) -ForegroundColor DarkGray
                
                $compileResults = Compile-MQ5Files -MT5Path $installation.Path -FilesToCompile $filesToCompile -ShowOutput:$false
                
                $totalCompileResults.Success += $compileResults.Success
                $totalCompileResults.Failed += $compileResults.Failed
                $totalCompileResults.Total += $compileResults.Total
                
                # Afficher les résultats pour cette installation
                if ($compileResults.Success -gt 0) {
                    Write-Host ("       [OK] Compilés : {0}" -f $compileResults.Success) -ForegroundColor Green
                }
                if ($compileResults.Failed -gt 0) {
                    Write-Host ("       [X] Échecs : {0}" -f $compileResults.Failed) -ForegroundColor Red
                }
            }
            else {
                Write-Host "     [!] Aucun fichier .mq5 à compiler" -ForegroundColor DarkGray
            }
        }
        
        # Mettre à jour les résultats globaux de compilation
        $Script:DeployState.CompileResults.Success += $totalCompileResults.Success
        $Script:DeployState.CompileResults.Failed += $totalCompileResults.Failed
        $Script:DeployState.CompileResults.Total += $totalCompileResults.Total
        
        Write-Host ""
        Write-Host "================================================" -ForegroundColor Yellow
        Write-Host ("        COMPILATION TERMINEE : {0,-18} " -f $Type.ToUpper()) -ForegroundColor Yellow
        Write-Host "================================================" -ForegroundColor Yellow
        Write-Host ""
    }
    
    Write-Host ""
    return $results
}

function Show-InteractiveMenu {
    param(
        [array]$Installations,
        [hashtable]$SourceData
    )
    
    if (-not $Installations -or $Installations.Count -eq 0) {
        Show-Header -State $Script:DeployState -CurrentStep "Erreur"
        Write-ColorOutput "[X] Aucune installation disponible" -Level Error
        return
    }
    
    # Initialiser l'état
    $Script:DeployState.InstallationCount = $Installations.Count
    $Script:DeployState.FileCount = @{
        EA = $SourceData['EA'].Count
        Indicators = $SourceData['Indicators'].Count
        Shared = $SourceData['Shared'].Count
    }
    
    # ═══════════════════════════════════════════════════════════════
    # ÉTAPE 1 : Afficher les installations disponibles
    # ═══════════════════════════════════════════════════════════════
    Show-Header -State $Script:DeployState -CurrentStep "Informations système"
    
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host "        INSTALLATIONS MT5 DETECTEES                " -ForegroundColor Cyan
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host ""
    
    for ($i = 0; $i -lt $Installations.Count; $i++) {
        Write-Host ("  [{0}] {1}" -f ($i + 1), $Installations[$i].Name) -ForegroundColor Green
        Write-Host ("      [DIR] {0}" -f $Installations[$i].Path) -ForegroundColor DarkGray
        Write-Host ""
    }
    
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host "        FICHIERS SOURCES DISPONIBLES               " -ForegroundColor Cyan
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($type in @('EA', 'Indicators', 'Shared')) {
        $count = $SourceData[$type].Count
        $icon = if ($count -gt 0) { "[OK]" } else { "[X]" }
        $color = if ($count -gt 0) { "Green" } else { "Red" }
        Write-Host ("  $icon {0,-12} : {1} fichier(s)" -f $type, $count) -ForegroundColor $color
    }
    Write-Host ""
    
    Write-Host "Appuyez sur une touche pour continuer..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    
    # ═══════════════════════════════════════════════════════════════
    # ÉTAPE 2 : Sélection du type
    # ═══════════════════════════════════════════════════════════════
    Show-Header -State $Script:DeployState -CurrentStep "Sélection du type de fichiers"
    
    Write-Host "================================================" -ForegroundColor Yellow
    Write-Host "        QUE SOUHAITEZ-VOUS DEPLOYER ?              " -ForegroundColor Yellow
    Write-Host "================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [1] [EA] Expert Advisors uniquement" -ForegroundColor White
    Write-Host "  [2] [IND] Indicateurs uniquement" -ForegroundColor White
    Write-Host "  [3] [SH] Shared (dependances) uniquement" -ForegroundColor White
    Write-Host "  [4] [ALL] Tout deployer" -ForegroundColor White
    Write-Host ""
    Write-Host "  [0] [X] Quitter" -ForegroundColor Red
    
    $typeChoice = Get-MenuChoice -Prompt "Votre choix (0-4):" -ValidChoices @('0','1','2','3','4') -AllowEscape
    
    if ($typeChoice -eq '0' -or $null -eq $typeChoice) {
        Show-Header -State $Script:DeployState -CurrentStep "Annulation"
        Write-ColorOutput "[X] Deploiement annule" -Level Warning
        Start-Sleep -Seconds 2
        return
    }
    
    # Mapping et mise à jour de l'état
    $typeMapping = @{
        '1' = @{ Type = 'EA'; Display = 'Expert Advisors' }
        '2' = @{ Type = 'Indicators'; Display = 'Indicateurs' }
        '3' = @{ Type = 'Shared'; Display = 'Shared (dépendances)' }
        '4' = @{ Type = 'All'; Display = 'Tout déployer' }
    }
    $selectedType = $typeMapping[$typeChoice].Type
    $Script:DeployState.SelectedType = $typeMapping[$typeChoice].Display
    
    # ═══════════════════════════════════════════════════════════════
    # ÉTAPE 3 : Sélection des installations
    # ═══════════════════════════════════════════════════════════════
    Show-Header -State $Script:DeployState -CurrentStep "Sélection des installations cibles"
    
    Write-Host "================================================" -ForegroundColor Yellow
    Write-Host "        VERS QUELLE(S) INSTALLATION(S) ?           " -ForegroundColor Yellow
    Write-Host "================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [1] [ALL] Toutes les installations ($($Installations.Count))" -ForegroundColor White
    Write-Host "  [2] [SEL] Selection specifique" -ForegroundColor White
    
    $installChoice = Get-MenuChoice -Prompt "Votre choix (1-2):" -ValidChoices @('1','2')
    
    $selectedInstallations = @()
    if ($installChoice -eq '1') {
        $selectedInstallations = $Installations
        $Script:DeployState.SelectedInstallations = "Toutes ($($Installations.Count))"
    }
    else {
        # Afficher menu de sélection spécifique
        Show-Header -State $Script:DeployState -CurrentStep "Sélection spécifique des installations"
        
        Write-Host "================================================" -ForegroundColor Yellow
        Write-Host "        SELECTIONNEZ LES INSTALLATIONS             " -ForegroundColor Yellow
        Write-Host "================================================" -ForegroundColor Yellow
        Write-Host ""
        
        for ($i = 0; $i -lt $Installations.Count; $i++) {
            Write-Host ("  [{0}] {1}" -f ($i + 1), $Installations[$i].Name) -ForegroundColor White
            Write-Host ("      [DIR] {0}" -f $Installations[$i].Path) -ForegroundColor DarkGray
            Write-Host ""
        }
        Write-Host "  [A] Toutes les installations" -ForegroundColor Green
        Write-Host ""
        
        $selection = Read-Host "Votre sélection (ex: 1,3 ou A)"
        
        if ($selection -eq 'A' -or $selection -eq 'a') {
            $selectedInstallations = $Installations
            $Script:DeployState.SelectedInstallations = "Toutes ($($Installations.Count))"
        }
        else {
            $indices = $selection -split ',' | ForEach-Object { 
                $trimmed = $_.Trim()
                if ($trimmed -match '^\d+$') {
                    [int]$trimmed - 1
                }
            }
            
            $selectedInstallations = $indices | Where-Object { 
                $_ -ge 0 -and $_ -lt $Installations.Count 
            } | ForEach-Object { 
                $Installations[$_] 
            }
            
            $Script:DeployState.SelectedInstallations = "$($selectedInstallations.Count) installation(s)"
        }
    }
    
    if ($selectedInstallations.Count -eq 0) {
        Show-Header -State $Script:DeployState -CurrentStep "Erreur"
        Write-ColorOutput "[X] Aucune installation selectionnee" -Level Error
        Start-Sleep -Seconds 2
        return
    }
    
    # ═══════════════════════════════════════════════════════════════
    # ÉTAPE 4 : Option backup
    # ═══════════════════════════════════════════════════════════════
    Show-Header -State $Script:DeployState -CurrentStep "Configuration des sauvegardes"
    
    Write-Host "================================================" -ForegroundColor Yellow
    Write-Host "        CREER DES SAUVEGARDES ?                    " -ForegroundColor Yellow
    Write-Host "================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [1] [OK] Oui (recommandé)" -ForegroundColor Green
    Write-Host "      Sauvegarde les fichiers existants avant ecrasement" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [2] [!] Non" -ForegroundColor Yellow
    Write-Host "      Les fichiers existants seront ecrases sans sauvegarde" -ForegroundColor DarkGray
    
    $backupChoice = Get-MenuChoice -Prompt "Votre choix (1-2):" -ValidChoices @('1','2')
    $createBackup = ($backupChoice -eq '1')
    $Script:DeployState.CreateBackup = if ($createBackup) { "Oui" } else { "Non" }
    
    # ═══════════════════════════════════════════════════════════════
    # ÉTAPE 5 : Option de compilation
    # ═══════════════════════════════════════════════════════════════
    Show-Header -State $Script:DeployState -CurrentStep "Configuration de la compilation"
    
    Write-Host "================================================" -ForegroundColor Yellow
    Write-Host "        COMPILER LES FICHIERS APRES DEPLOIEMENT ?    " -ForegroundColor Yellow
    Write-Host "================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [1] [OK] Oui (génère les .ex5)" -ForegroundColor Green
    Write-Host "      Compile automatiquement les fichiers .mq5 vers .ex5" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [2] [!] Non (seulement copier les .mq5)" -ForegroundColor Yellow
    Write-Host "      Les fichiers .mq5 seront copiés sans compilation" -ForegroundColor DarkGray
    
    $compileChoice = Get-MenuChoice -Prompt "Votre choix (1-2):" -ValidChoices @('1','2')
    $CompileAfterDeploy = ($compileChoice -eq '1')
    $Script:DeployState.CompileAfterDeploy = if ($CompileAfterDeploy) { "Oui" } else { "Non" }
    
    # ═══════════════════════════════════════════════════════════════
    # ÉTAPE 6 : Confirmation finale
    # ═══════════════════════════════════════════════════════════════
    Show-Header -State $Script:DeployState -CurrentStep "Confirmation finale"
    
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host "        RECAPITULATIF DU DEPLOIEMENT              " -ForegroundColor Cyan
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Afficher le récapitulatif détaillé
    Write-Host "  [*] Type             : $($Script:DeployState.SelectedType)" -ForegroundColor White
    Write-Host "  [*] Installations   : $($Script:DeployState.SelectedInstallations)" -ForegroundColor White
    Write-Host "  [*] Sauvegardes      : $($Script:DeployState.CreateBackup)" -ForegroundColor White
    Write-Host "  [*] Compilation      : $($Script:DeployState.CompileAfterDeploy)" -ForegroundColor White
    Write-Host "  [*] Destination EA   : $($Script:Config.TargetSubdirs['EA'])" -ForegroundColor DarkGray
    Write-Host ""
    
    Write-Host "  Fichiers a deployer :" -ForegroundColor Yellow
    if ($selectedType -eq 'All' -or $selectedType -eq 'EA') {
        Write-Host "    - EA        : $($SourceData['EA'].Count) fichier(s)" -ForegroundColor Green
    }
    if ($selectedType -eq 'All' -or $selectedType -eq 'Indicators') {
        Write-Host "    - Indicators: $($SourceData['Indicators'].Count) fichier(s)" -ForegroundColor Green
    }
    if ($selectedType -eq 'All' -or $selectedType -eq 'Shared') {
        Write-Host "    - Shared    : $($SourceData['Shared'].Count) fichier(s)" -ForegroundColor Green
    }
    Write-Host ""
    
    Write-Host "================================================" -ForegroundColor Yellow
    Write-Host "        CONFIRMER LE DEPLOIEMENT ?                 " -ForegroundColor Yellow
    Write-Host "================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [1] [OK] Continuer" -ForegroundColor Green
    Write-Host "  [2] [X] Annuler" -ForegroundColor Red
    
    $confirm = Get-MenuChoice -Prompt "Votre choix (1-2):" -ValidChoices @('1','2')
    
    if ($confirm -ne '1') {
        Show-Header -State $Script:DeployState -CurrentStep "Annulation"
        Write-ColorOutput "[X] Deploiement annule" -Level Warning
        Start-Sleep -Seconds 2
        return
    }
    
    # ═══════════════════════════════════════════════════════════════
    # ÉTAPE 7 : Déploiement
    # ═══════════════════════════════════════════════════════════════
    $Script:DeployState.Deploying = $true
    Show-Header -State $Script:DeployState -CurrentStep "Déploiement en cours..."
    
    Execute-Deployment -Type $selectedType -Installations $selectedInstallations -SourceData $SourceData -CreateBackup:$createBackup -CompileAfterDeploy:$CompileAfterDeploy
}

function Execute-Deployment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('EA', 'Indicators', 'Shared', 'All')]
        [string]$Type,
        
        [Parameter(Mandatory)]
        [array]$Installations,
        
        [Parameter(Mandatory)]
        [hashtable]$SourceData,
        
        [Parameter()]
        [switch]$CreateBackup,
        
        [Parameter()]
        [switch]$CompileAfterDeploy
    )
    
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host "DEMARRAGE DU DEPLOIEMENT" -ForegroundColor Cyan
    Write-Host "================================================" -ForegroundColor Cyan
    
    $totalResults = @{ Success = 0; Failed = 0 }
    
    # ✅ ORDRE DE DÉPLOIEMENT IMPORTANT:
    # 1. Shared d'abord (toutes les dépendances globales)
    # 2. Indicators
    # 3. EA (avec copie automatique de leurs dépendances spécifiques)
    if ($Type -eq 'All') {
        # Déployer dans l'ordre optimal
        foreach ($deployType in @('Shared', 'Indicators', 'EA')) {
            if ($SourceData[$deployType].Count -gt 0) {
                $results = Deploy-FilesByType `
                    -Type $deployType `
                    -Installations $Installations `
                    -SourceInfo $SourceData[$deployType] `
                    -CreateBackup:$CreateBackup `
                    -CompileAfterDeploy:$CompileAfterDeploy
                
                $totalResults.Success += $results.Success
                $totalResults.Failed += $results.Failed
            }
        }
    }
    else {
        # Type specifique (EA, Indicators, ou Shared)
        if ($SourceData[$Type].Count -gt 0) {
            $results = Deploy-FilesByType `
                -Type $Type `
                -Installations $Installations `
                -SourceInfo $SourceData[$Type] `
                -CreateBackup:$CreateBackup `
                -CompileAfterDeploy:$CompileAfterDeploy
            
            $totalResults.Success += $results.Success
            $totalResults.Failed += $results.Failed
        }
    }
    
    # Rapport final
    Show-FinalReport -Results $totalResults -Installations $Installations
}

function Show-FinalReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Results,
        
        [Parameter(Mandatory)]
        [array]$Installations
    )
    
    # ✅ Nettoyer et afficher header final
    $Script:DeployState.Remove('Deploying')
    Show-Header -State $Script:DeployState -CurrentStep "Déploiement terminé"
    
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host "        RAPPORT DE DEPLOIEMENT                     " -ForegroundColor Cyan
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Installations cibles
    Write-Host "[*] Installations cibles :" -ForegroundColor Yellow
    foreach ($installation in $Installations) {
        Write-Host ("   - {0}" -f $installation.Name) -ForegroundColor White
        Write-Host ("     [DIR] {0}" -f $installation.Path) -ForegroundColor DarkGray
    }
    Write-Host ""
    
    # Résultats
    Write-Host "[*] Resultats du deploiement :" -ForegroundColor Yellow
    Write-Host ("   [OK] Succes : {0}" -f $Results.Success) -ForegroundColor Green
    
    if ($Results.Failed -gt 0) {
        Write-Host ("   [X] Echecs : {0}" -f $Results.Failed) -ForegroundColor Red
    }
    Write-Host ""
    
    # ✅ NOUVEAU: Résultats de compilation
    if ($Script:DeployState.CompileResults.Total -gt 0) {
        Write-Host "[*] Resultats de compilation :" -ForegroundColor Yellow
        Write-Host ("   [OK] Compilés : {0}" -f $Script:DeployState.CompileResults.Success) -ForegroundColor Green
        
        if ($Script:DeployState.CompileResults.Failed -gt 0) {
            Write-Host ("   [X] Échecs : {0}" -f $Script:DeployState.CompileResults.Failed) -ForegroundColor Red
        }
        Write-Host ""
    }
    
    # Structure de déploiement
    Write-Host "[*] Structure de deploiement :" -ForegroundColor Yellow
    Write-Host "   - Indicators -> MQL5\Indicators\" -ForegroundColor DarkGray
    Write-Host "   - Shared     -> MQL5\Shared\" -ForegroundColor DarkGray
    Write-Host "   - EA         -> MQL5\Experts\EA\ (+ dependances .mqh)" -ForegroundColor DarkGray
    
    if ($Script:DeployState.CompileResults.Total -gt 0) {
        Write-Host "   - Compilation -> .mq5 vers .ex5 (MetaEditor)" -ForegroundColor DarkGray
    }
    Write-Host ""
    
    # Message final avec cadre
    $hasCompileErrors = $Script:DeployState.CompileResults.Failed -gt 0
    $hasDeployErrors = $Results.Failed -gt 0
    
    if (-not $hasDeployErrors -and -not $hasCompileErrors) {
        Write-Host "================================================" -ForegroundColor Green
        Write-Host "   [OK] DEPLOIEMENT TERMINE AVEC SUCCES !            " -ForegroundColor Green
        if ($Script:DeployState.CompileResults.Total -gt 0) {
            Write-Host "   [OK] COMPILATION TERMINEE AVEC SUCCES !          " -ForegroundColor Green
        }
        Write-Host "================================================" -ForegroundColor Green
    }
    elseif (-not $hasDeployErrors -and $hasCompileErrors) {
        Write-Host "================================================" -ForegroundColor Yellow
        Write-Host "   [OK] DEPLOIEMENT TERMINE AVEC SUCCES !            " -ForegroundColor Green
        Write-Host "   [!] COMPILATION TERMINEE AVEC DES ERREURS !        " -ForegroundColor Yellow
        Write-Host "================================================" -ForegroundColor Yellow
    }
    else {
        Write-Host "================================================" -ForegroundColor Yellow
        Write-Host "   [!] DEPLOIEMENT TERMINE AVEC DES ERREURS !      " -ForegroundColor Yellow
        if ($Script:DeployState.CompileResults.Total -gt 0) {
            Write-Host "   [!] COMPILATION TERMINEE AVEC DES ERREURS !        " -ForegroundColor Yellow
        }
        Write-Host "================================================" -ForegroundColor Yellow
    }
    Write-Host ""
    
    Write-Host "Appuyez sur une touche pour quitter..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

function Invoke-Main {
    [CmdletBinding()]
    param()
    
    try {
        Write-Host ""
        Write-ColorOutput "================================================" -Level Info
        Write-ColorOutput "  DEPLOIEMENT MT5 - RSI DIVERGENCE SYSTEM" -Level Info
        Write-ColorOutput "================================================" -Level Info
        Write-Host ""
        
        # Detection des installations MT5
        $installations = Find-MT5Installations
        
        if ($installations.Count -eq 0) {
            Write-ColorOutput "`n- Aucune installation MetaTrader 5 trouvee!" -Level Error
            Write-ColorOutput "   Verifiez que MT5 est installe dans les emplacements standards." -Level Warning
            return
        }
        
        # Validation des fichiers sources
        $sourceData = Get-SourceFiles
        
        # Verifier qu'il y a au moins des fichiers a deployer
        $totalFiles = ($sourceData.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
        if ($totalFiles -eq 0) {
            Write-ColorOutput "`n- Aucun fichier source trouve!" -Level Error
            Write-ColorOutput "   Verifiez que les dossiers EA, Indicators et Shared contiennent des fichiers." -Level Warning
            return
        }
        
        # Mode silencieux
        if ($Silent) {
            Write-ColorOutput "`nMode silencieux active" -Level Info
            
            # Determiner les installations cibles
            $targetInstallations = if ($AllInstallations) {
                $installations
            }
            elseif ($TargetPath) {
                $match = $installations | Where-Object { $_.Path -eq $TargetPath }
                if (-not $match) {
                    Write-ColorOutput "`n- Installation introuvable: $TargetPath" -Level Error
                    return
                }
                @($match)  # Forcer en tableau
            }
            else {
                @($installations[0])  # Forcer en tableau (premiere installation par defaut)
            }
            
            # Appeler avec CreateBackup et CompileAfterDeploy
            Execute-Deployment `
                -Type $Type `
                -Installations $targetInstallations `
                -SourceData $sourceData `
                -CreateBackup:$CreateBackup `
                -CompileAfterDeploy:$CompileAfterDeploy
        }
        else {
            # Mode interactif
            Show-InteractiveMenu -Installations $installations -SourceData $sourceData
        }
    }
    catch {
        Write-Host ""
        Write-ColorOutput "================================================" -Level Error
        Write-ColorOutput "- ERREUR FATALE" -Level Error
        Write-ColorOutput "================================================" -Level Error
        Write-ColorOutput $_.Exception.Message -Level Error
        Write-ColorOutput "`nStack Trace:" -Level Error
        Write-ColorOutput $_.ScriptStackTrace -Level Error
        
        Write-Host ""
        Write-ColorOutput "Appuyez sur une touche pour quitter..." -Level Info
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        
        throw
    }
}

# Point d'entree du script
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Main
}   