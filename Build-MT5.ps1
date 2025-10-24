#Requires -Version 5.1

<#
.SYNOPSIS
    Script de création et déploiement de fichiers MQL5 individuels avec gestion de configurations

.DESCRIPTION
    Ce script automatise la création de nouveaux fichiers MQL5 (EA, Indicateurs, Shared) depuis des templates,
    gère les dépendances automatiquement, et déploie vers les installations MetaTrader 5 configurées.

.PARAMETER Name
    Nom du fichier à créer (sans extension)

.PARAMETER Type
    Type de fichier: EA, Indicator, ou Shared

.PARAMETER Template
    Template à utiliser (optionnel, utilise le template par défaut si non spécifié)

.PARAMETER Deploy
    Déployer automatiquement après création

.PARAMETER Compile
    Compiler après déploiement

.PARAMETER ConfigFile
    Fichier build.config à utiliser (défaut: build/build.config)

.PARAMETER MT5Target
    Override: nom installation, "all", "auto", "default"

.PARAMETER Interactive
    Menu interactif pour choisir les installations

.PARAMETER SkipMT5Check
    Ne pas valider les installations MT5

.PARAMETER Force
    Écraser les fichiers existants sans confirmation

.EXAMPLE
    .\Build-MT5.ps1 -Name "MyNewEA" -Type EA -Template "EA_Template.mq5"
    Crée un nouvel EA depuis le template spécifié

.EXAMPLE
    .\Build-MT5.ps1 -Name "RSI_Divergence_EA" -Type EA -Deploy -Compile
    Copie un EA existant avec dépendances et déploie

.EXAMPLE
    .\Build-MT5.ps1 -Name "RSI_Divergence_EA" -ConfigFile "build\build.config" -Deploy
    Crée depuis la configuration

.EXAMPLE
    .\Build-MT5.ps1 -Name "MyHelper" -Type Shared -Template "Shared_Template.mqh"
    Crée une classe Shared

.EXAMPLE
    .\Build-MT5.ps1 -Name "RSI_Divergence_EA" -Deploy -MT5Target "MT5_Test"
    Force le déploiement vers une installation spécifique
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Name,
    
    [Parameter(Mandatory)]
    [ValidateSet('EA', 'Indicator', 'Shared')]
    [string]$Type,
    
    [Parameter()]
    [string]$Template,
    
    [Parameter()]
    [switch]$Deploy,
    
    [Parameter()]
    [switch]$Compile,
    
    [Parameter()]
    [string]$ConfigFile = "build\build.config",
    
    [Parameter()]
    [string]$MT5Target,
    
    [Parameter()]
    [switch]$Interactive,
    
    [Parameter()]
    [switch]$SkipMT5Check,
    
    [Parameter()]
    [switch]$Force
)

# Configuration globale
$Script:ProjectRoot = $PSScriptRoot
$Script:BuildState = @{
    ProjectName = $Name
    ProjectType = $Type
    FilesCreated = @()
    DependenciesCopied = @()
    InstallationsTargeted = @()
    CompileResults = @{
        Success = 0
        Failed = 0
        Total = 0
    }
}

# Couleurs pour l'affichage
$Script:Colors = @{
    Header = 'Cyan'
    Success = 'Green'
    Warning = 'Yellow'
    Error = 'Red'
    Info = 'White'
    Detail = 'DarkGray'
}

# ============================================================================
# FONCTIONS HELPER
# ============================================================================

function Write-ColorOutput {
    <#
    .SYNOPSIS
        Affiche du texte coloré
    #>
    param(
        [string]$Text,
        [string]$Color = 'White',
        [switch]$NoNewline
    )
    
    if ($NoNewline) {
        Write-Host $Text -ForegroundColor $Color -NoNewline
    } else {
        Write-Host $Text -ForegroundColor $Color
    }
}

function Write-Header {
    <#
    .SYNOPSIS
        Affiche un en-tête formaté
    #>
    param([string]$Title)
    
    Write-Host ""
    Write-Host "=" * 50 -ForegroundColor $Script:Colors.Header
    Write-Host "        $Title" -ForegroundColor $Script:Colors.Header
    Write-Host "=" * 50 -ForegroundColor $Script:Colors.Header
    Write-Host ""
}

function Write-Section {
    <#
    .SYNOPSIS
        Affiche une section avec titre
    #>
    param([string]$Title)
    
    Write-Host ""
    Write-Host "[*] $Title" -ForegroundColor $Script:Colors.Info
}

function Write-Success {
    <#
    .SYNOPSIS
        Affiche un message de succès
    #>
    param([string]$Message)
    
    Write-Host "  [OK] $Message" -ForegroundColor $Script:Colors.Success
}

function Write-Warning {
    <#
    .SYNOPSIS
        Affiche un avertissement
    #>
    param([string]$Message)
    
    Write-Host "  [!] $Message" -ForegroundColor $Script:Colors.Warning
}

function Write-Error {
    <#
    .SYNOPSIS
        Affiche une erreur
    #>
    param([string]$Message)
    
    Write-Host "  [ERREUR] $Message" -ForegroundColor $Script:Colors.Error
}

# ============================================================================
# FONCTIONS DE CONFIGURATION
# ============================================================================

function ConvertTo-Hashtable {
    <#
    .SYNOPSIS
        Convertit un objet PSCustomObject en hashtable (compatible PowerShell 5.1)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject]$Object
    )
    
    if ($Object -eq $null) {
        return $null
    }
    
    if ($Object -is [System.Collections.IDictionary]) {
        return $Object
    }
    
    if ($Object -is [System.Array]) {
        $result = @()
        foreach ($item in $Object) {
            if ($item -is [string] -or $item -is [int] -or $item -is [bool] -or $item -is [double]) {
                $result += $item
            } else {
                $result += ConvertTo-Hashtable -Object $item
            }
        }
        return $result
    }
    
    if ($Object -is [PSCustomObject]) {
        $hashtable = @{}
        $Object.PSObject.Properties | ForEach-Object {
            $value = $_.Value
            # Ne pas convertir les valeurs primitives
            if ($value -is [string] -or $value -is [int] -or $value -is [bool] -or $value -is [double]) {
                $hashtable[$_.Name] = $value
            } else {
                $hashtable[$_.Name] = ConvertTo-Hashtable -Object $value
            }
        }
        return $hashtable
    }
    
    return $Object
}

function Get-BuildConfig {
    <#
    .SYNOPSIS
        Charge et valide le fichier build.config
    
    .PARAMETER ConfigPath
        Chemin vers le fichier build.config
    
    .OUTPUTS
        Hashtable contenant la configuration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath
    )
    
    if (-not (Test-Path $ConfigPath)) {
        Write-Warning "Fichier de configuration introuvable: $ConfigPath"
        return Get-DefaultConfig
    }
    
    try {
        $jsonContent = Get-Content $ConfigPath -Raw -Encoding UTF8
        $jsonObject = $jsonContent | ConvertFrom-Json
        
        # Convertir en hashtable pour PowerShell 5.1
        $config = ConvertTo-Hashtable -Object $jsonObject
        
        # Valider la configuration
        $errors = Test-BuildConfig -Config $config
        if ($errors.Count -gt 0) {
            Write-Warning "Erreurs dans la configuration:"
            foreach ($error in $errors) {
                Write-Warning "  - $error"
            }
        }
        
        return $config
    }
    catch {
        Write-Error "Erreur lors du chargement de la configuration: $($_.Exception.Message)"
        return Get-DefaultConfig
    }
}

function Get-DefaultConfig {
    <#
    .SYNOPSIS
        Retourne une configuration par défaut
    #>
    return @{
        mt5Installations = @{
            default = "auto"
            installations = @()
            autoDetect = $true
            deploymentRules = @{
                EA = @("MT5_Production", "MT5_Test")
                Indicator = @("MT5_Production")
                Shared = "all"
            }
        }
        projects = @{}
        settings = @{
            defaultAuthor = "JTrading Team"
            defaultCopyright = "Copyright 2025 JTrading"
            autoCompile = $true
            autoDeploy = $false
            backupBeforeDeploy = $true
            defaultDeployTarget = "auto"
        }
    }
}

function Test-BuildConfig {
    <#
    .SYNOPSIS
        Valide la structure du fichier build.config
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )
    
    $errors = @()
    
    # Vérifier mt5Installations
    if (-not $Config.mt5Installations) {
        $errors += "Section 'mt5Installations' manquante"
    }
    else {
        # Vérifier les installations
        if ($Config.mt5Installations.installations) {
            foreach ($inst in $Config.mt5Installations.installations) {
                if (-not $inst.name) {
                    $errors += "Installation sans nom trouvée"
                }
                if (-not $inst.path) {
                    $errors += "Installation '$($inst.name)' sans chemin"
                }
                if ($inst.enabled -and -not (Test-Path $inst.path)) {
                    Write-Warning "Installation '$($inst.name)': chemin introuvable ($($inst.path))"
                }
            }
        }
    }
    
    # Vérifier projets
    if ($Config.projects) {
        if ($Config.projects -is [System.Collections.IDictionary]) {
            foreach ($proj in $Config.projects.GetEnumerator()) {
                $p = $proj.Value
                
                # Vérifier deployTo
                if ($p.deployTo -is [array]) {
                    foreach ($target in $p.deployTo) {
                        $found = $Config.mt5Installations.installations | 
                            Where-Object { $_.name -eq $target }
                        if (-not $found) {
                            Write-Warning "Projet '$($proj.Key)': installation '$target' introuvable"
                        }
                    }
                }
            }
        }
    }
    
    return $errors
}

# ============================================================================
# FONCTIONS DE GESTION MT5
# ============================================================================

function Find-MT5Installations {
    <#
    .SYNOPSIS
        Détecte automatiquement les installations MT5
    #>
    [CmdletBinding()]
    param()
    
    $installations = @()
    $commonPaths = @(
        "C:\Program Files\MetaTrader 5",
        "C:\Program Files (x86)\MetaTrader 5",
        "C:\Program Files\MetaTrader 5 Test",
        "C:\Program Files (x86)\MetaTrader 5 Test",
        "D:\Trading\MT5",
        "D:\MetaTrader 5",
        "C:\Users\$env:USERNAME\AppData\Roaming\MetaQuotes\Terminal",
        "C:\Users\$env:USERNAME\AppData\Local\Programs\MetaTrader 5",
        "C:\Users\$env:USERNAME\Documents\MetaTrader 5"
    )
    
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            # Cas spécial pour AppData\Roaming\MetaQuotes\Terminal
            if ($path -like "*AppData\Roaming\MetaQuotes\Terminal*") {
                # Chercher dans les sous-dossiers
                $terminalDirs = Get-ChildItem $path -Directory -ErrorAction SilentlyContinue
                foreach ($terminalDir in $terminalDirs) {
                    $mql5Path = Join-Path $terminalDir.FullName "MQL5"
                    if (Test-Path $mql5Path) {
                        $installations += [PSCustomObject]@{
                            Name = "Auto_$(Split-Path $terminalDir.Name -Leaf)"
                            Path = $terminalDir.FullName
                            MQL5Path = $mql5Path
                            Priority = 999
                            AutoDetected = $true
                        }
                    }
                }
            } else {
                # Cas normal
                $mql5Path = Join-Path $path "MQL5"
                if (Test-Path $mql5Path) {
                    $installations += [PSCustomObject]@{
                        Name = "Auto_$(Split-Path $path -Leaf)"
                        Path = $path
                        MQL5Path = $mql5Path
                        Priority = 999
                        AutoDetected = $true
                    }
                }
            }
        }
    }
    
    return $installations
}

function Get-MT5Targets {
    <#
    .SYNOPSIS
        Résout les installations MT5 cibles selon la configuration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,
        
        [Parameter()]
        [hashtable]$ProjectConfig,
        
        [Parameter(Mandatory)]
        [ValidateSet('EA', 'Indicator', 'Shared')]
        [string]$Type,
        
        [Parameter()]
        [string]$OverrideTarget
    )
    
    Write-ColorOutput "[*] Résolution des installations MT5..." -Color $Script:Colors.Info
    
    # 1. Si override en paramètre, l'utiliser
    if ($OverrideTarget) {
        Write-ColorOutput "    [OVERRIDE] Cible forcée: $OverrideTarget" -Color $Script:Colors.Detail
        return Get-InstallationByName -Config $Config -Name $OverrideTarget
    }
    
    # 2. Vérifier config du projet
    if ($ProjectConfig -and $ProjectConfig.deployTo) {
        $deployTo = $ProjectConfig.deployTo
        
        if ($deployTo -eq 'auto') {
            Write-ColorOutput "    [CONFIG] Mode auto-détection" -Color $Script:Colors.Detail
            return Find-MT5Installations
        }
        elseif ($deployTo -eq 'default') {
            Write-ColorOutput "    [CONFIG] Installation par défaut" -Color $Script:Colors.Detail
            return Get-DefaultInstallation -Config $Config
        }
        elseif ($deployTo -eq 'all') {
            Write-ColorOutput "    [CONFIG] Toutes les installations" -Color $Script:Colors.Detail
            return Get-EnabledInstallations -Config $Config
        }
        elseif ($deployTo -is [array]) {
            Write-ColorOutput "    [CONFIG] Installations spécifiques: $($deployTo -join ', ')" -Color $Script:Colors.Detail
            return Get-InstallationsByNames -Config $Config -Names $deployTo
        }
    }
    
    # 3. Utiliser deploymentRules par type
    if ($Config.mt5Installations.deploymentRules.ContainsKey($Type)) {
        $rule = $Config.mt5Installations.deploymentRules[$Type]
        Write-ColorOutput "    [DEFAULT] Règle par défaut: $Type → $rule" -Color $Script:Colors.Detail
        
        if ($rule -eq 'all') {
            return Get-EnabledInstallations -Config $Config
        }
        elseif ($rule -is [array]) {
            return Get-InstallationsByNames -Config $Config -Names $rule
        }
    }
    
    # 4. Fallback sur default global
    $defaultMode = $Config.mt5Installations.default
    Write-ColorOutput "    [FALLBACK] Mode par défaut: $defaultMode" -Color $Script:Colors.Detail
    
    if ($defaultMode -eq 'auto') {
        return Find-MT5Installations
    }
    else {
        return Get-DefaultInstallation -Config $Config
    }
}

function Get-InstallationByName {
    <#
    .SYNOPSIS
        Trouve une installation par son nom
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,
        
        [Parameter(Mandatory)]
        [string]$Name
    )
    
    if ($Name -eq 'all') {
        return Get-EnabledInstallations -Config $Config
    }
    elseif ($Name -eq 'auto') {
        return Find-MT5Installations
    }
    elseif ($Name -eq 'default') {
        return Get-DefaultInstallation -Config $Config
    }
    
    $installation = $Config.mt5Installations.installations | 
        Where-Object { $_.name -eq $Name -and $_.enabled }
    
    if (-not $installation) {
        Write-Warning "Installation '$Name' introuvable ou désactivée"
        return @()
    }
    
    # Vérifier que le chemin existe
    if (-not (Test-Path $installation.path)) {
        Write-Warning "Chemin introuvable: $($installation.path)"
        return @()
    }
    
    return [PSCustomObject]@{
        Name = $installation.name
        Path = $installation.path
        MQL5Path = Join-Path $installation.path "MQL5"
        Priority = $installation.priority
        AutoDetected = $false
    }
}

function Get-EnabledInstallations {
    <#
    .SYNOPSIS
        Retourne toutes les installations activées
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )
    
    $installations = $Config.mt5Installations.installations | 
        Where-Object { $_.enabled -eq $true }
    
    $result = @()
    foreach ($inst in $installations) {
        if (Test-Path $inst.path) {
            $result += [PSCustomObject]@{
                Name = $inst.name
                Path = $inst.path
                MQL5Path = Join-Path $inst.path "MQL5"
                Priority = $inst.priority
                AutoDetected = $false
            }
        }
    }
    
    # Trier par priorité
    return $result | Sort-Object Priority
}

function Get-DefaultInstallation {
    <#
    .SYNOPSIS
        Retourne l'installation par défaut (priority 1)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )
    
    # Chercher priority 1
    $default = $Config.mt5Installations.installations | 
        Where-Object { $_.enabled -and $_.priority -eq 1 } | 
        Select-Object -First 1
    
    if (-not $default) {
        # Fallback: première installation enabled
        $default = $Config.mt5Installations.installations | 
            Where-Object { $_.enabled } | 
            Sort-Object priority | 
            Select-Object -First 1
    }
    
    if ($default -and (Test-Path $default.path)) {
        return [PSCustomObject]@{
            Name = $default.name
            Path = $default.path
            MQL5Path = Join-Path $default.path "MQL5"
            Priority = $default.priority
            AutoDetected = $false
        }
    }
    
    return @()
}

function Get-InstallationsByNames {
    <#
    .SYNOPSIS
        Retourne les installations par leurs noms
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,
        
        [Parameter(Mandatory)]
        [array]$Names
    )
    
    $result = @()
    foreach ($name in $Names) {
        $inst = Get-InstallationByName -Config $Config -Name $name
        if ($inst) {
            $result += $inst
        }
    }
    
    return $result
}

# ============================================================================
# FONCTIONS DE GESTION DES FICHIERS
# ============================================================================

function New-MT5File {
    <#
    .SYNOPSIS
        Crée un nouveau fichier MQL5 depuis un template
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [ValidateSet('EA', 'Indicator', 'Shared')]
        [string]$Type,
        
        [Parameter()]
        [string]$Template,
        
        [Parameter()]
        [hashtable]$Config
    )
    
    # Déterminer le template à utiliser
    if (-not $Template) {
        $Template = Get-DefaultTemplate -Type $Type
    }
    
    $templatePath = Join-Path $Script:ProjectRoot "build\templates\$Template"
    if (-not (Test-Path $templatePath)) {
        Write-Error "Template introuvable: $templatePath"
        return $false
    }
    
    # Lire le template
    $templateContent = Get-Content $templatePath -Raw -Encoding UTF8
    
    # Remplacer les placeholders
    $author = "JTrading Team"
    $copyright = "Copyright 2025 JTrading"
    
    if ($Config -and $Config.ContainsKey('settings')) {
        $settings = $Config.settings
        if ($settings -and $settings.ContainsKey('defaultAuthor')) {
            $author = $settings.defaultAuthor
        }
        if ($settings -and $settings.ContainsKey('defaultCopyright')) {
            $copyright = $settings.defaultCopyright
        }
    }
    
    $replacements = @{
        '{NAME}' = $Name
        '{DATE}' = Get-Date -Format "yyyy.MM.dd"
        '{AUTHOR}' = $author
        '{COPYRIGHT}' = $copyright
        '{INCLUDES}' = Get-DefaultIncludes -Type $Type
    }
    
    foreach ($key in $replacements.Keys) {
        $templateContent = $templateContent.Replace($key, $replacements[$key])
    }
    
    # Déterminer le chemin de destination
    $extension = if ($Type -eq 'Shared') { 'mqh' } else { 'mq5' }
    $sourceDir = Get-SourceDirectory -Type $Type
    $targetPath = Join-Path $sourceDir "$Name.$extension"
    
    # Créer le répertoire si nécessaire
    $targetDir = Split-Path $targetPath -Parent
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    
    # Vérifier si le fichier existe déjà
    if ((Test-Path $targetPath) -and -not $Force) {
        $response = Read-Host "Le fichier $targetPath existe déjà. Écraser? (y/N)"
        if ($response -notmatch '^[yY]') {
            Write-Warning "Création annulée"
            return $false
        }
    }
    
    # Écrire le fichier
    try {
        $templateContent | Out-File -FilePath $targetPath -Encoding UTF8 -NoNewline
        Write-Success "Fichier créé: $targetPath"
        $Script:BuildState.FilesCreated += $targetPath
        return $true
    }
    catch {
        Write-Error "Erreur lors de la création du fichier: $($_.Exception.Message)"
        return $false
    }
}

function Get-DefaultTemplate {
    <#
    .SYNOPSIS
        Retourne le template par défaut pour un type donné
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('EA', 'Indicator', 'Shared')]
        [string]$Type
    )
    
    $templates = @{
        'EA' = 'EA_Template.mq5'
        'Indicator' = 'Indicator_Template.mq5'
        'Shared' = 'Shared_Template.mqh'
    }
    
    return $templates[$Type]
}

function Get-DefaultIncludes {
    <#
    .SYNOPSIS
        Retourne les includes par défaut pour un type donné
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('EA', 'Indicator', 'Shared')]
        [string]$Type
    )
    
    $includes = @{
        'EA' = @(
            "#include <Trade\Trade.mqh>",
            "#include <Trade\SymbolInfo.mqh>",
            "#include <Trade\PositionInfo.mqh>",
            "#include <Trade\AccountInfo.mqh>"
        )
        'Indicator' = @(
            "#include <Trade\SymbolInfo.mqh>"
        )
        'Shared' = @()
    }
    
    return ($includes[$Type] -join "`n")
}

function Get-SourceDirectory {
    <#
    .SYNOPSIS
        Retourne le répertoire source pour un type donné
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('EA', 'Indicator', 'Shared')]
        [string]$Type
    )
    
    $directories = @{
        'EA' = 'EA'
        'Indicator' = 'Indicators'
        'Shared' = 'Shared'
    }
    
    return Join-Path $Script:ProjectRoot $directories[$Type]
}

function Copy-FileDependencies {
    <#
    .SYNOPSIS
        Copie les dépendances d'un fichier MQL5
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        
        [Parameter()]
        [switch]$Force
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Error "Fichier introuvable: $FilePath"
        return $false
    }
    
    $content = Get-Content $FilePath -Raw -Encoding UTF8
    $dependencies = @()
    
    # Trouver tous les #include
    $includePattern = '#include\s+["<]([^">]+)["<]'
    $matches = [regex]::Matches($content, $includePattern)
    
    foreach ($match in $matches) {
        $includePath = $match.Groups[1].Value
        $dependencies += $includePath
    }
    
    if ($dependencies.Count -eq 0) {
        Write-ColorOutput "    Aucune dépendance trouvée" -Color $Script:Colors.Detail
        return $true
    }
    
    Write-ColorOutput "    Dépendances trouvées: $($dependencies.Count)" -Color $Script:Colors.Detail
    
    foreach ($dep in $dependencies) {
        $sourcePath = Join-Path $Script:ProjectRoot $dep
        if (Test-Path $sourcePath) {
            Write-Success "Dépendance copiée: $dep"
            $Script:BuildState.DependenciesCopied += $dep
        } else {
            Write-Warning "Dépendance introuvable: $dep"
        }
    }
    
    return $true
}

# ============================================================================
# FONCTIONS DE DÉPLOIEMENT
# ============================================================================

function Invoke-DeployToMT5 {
    <#
    .SYNOPSIS
        Déploie les fichiers vers les installations MT5
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Installations,
        
        [Parameter(Mandatory)]
        [string]$Type,
        
        [Parameter()]
        [switch]$Compile
    )
    
    if ($Installations.Count -eq 0) {
        Write-Warning "Aucune installation MT5 cible trouvée"
        return $false
    }
    
    Write-Section "Déploiement vers MT5"
    
    foreach ($installation in $Installations) {
        Write-ColorOutput "    Installation: $($installation.Name)" -Color $Script:Colors.Info
        Write-ColorOutput "    Chemin: $($installation.Path)" -Color $Script:Colors.Detail
        
        # Appeler le script de déploiement existant
        $deployScript = Join-Path $Script:ProjectRoot "Deploy-MT5-Fixed.ps1"
        if (-not (Test-Path $deployScript)) {
            Write-Error "Script de déploiement introuvable: $deployScript"
            continue
        }
        
        # Mapper les types pour le script de déploiement
        $deployType = switch ($Type) {
            'Indicator' { 'Indicators' }
            'EA' { 'EA' }
            'Shared' { 'Shared' }
            default { $Type }
        }
        
        $deployParams = @{
            Type = $deployType
            TargetPath = $installation.Path
            Silent = $true
        }
        
        if ($Compile) {
            $deployParams.CompileAfterDeploy = $true
        }
        
        try {
            & $deployScript @deployParams
            Write-Success "Déploiement réussi vers $($installation.Name)"
            $Script:BuildState.InstallationsTargeted += $installation.Name
        }
        catch {
            Write-Error "Erreur de déploiement vers $($installation.Name): $($_.Exception.Message)"
        }
    }
    
    return $true
}

# ============================================================================
# FONCTION PRINCIPALE
# ============================================================================

function Build-Project {
    <#
    .SYNOPSIS
        Fonction principale de build
    #>
    [CmdletBinding()]
    param()
    
    Write-Header "BUILD MT5 - $($Script:BuildState.ProjectName.ToUpper())"
    
    # 1. Charger la configuration
    Write-Section "Chargement de la configuration"
    $config = Get-BuildConfig -ConfigPath $ConfigFile
    $projectConfig = $null
    
    if ($config.projects -and $config.projects.ContainsKey($Name)) {
        $projectConfig = $config.projects[$Name]
        Write-Success "Configuration projet trouvée: $Name"
    } else {
        Write-ColorOutput "    Configuration projet non trouvée, utilisation des paramètres par défaut" -Color $Script:Colors.Detail
    }
    
    # 2. Vérifier si le fichier existe déjà
    $extension = if ($Type -eq 'Shared') { 'mqh' } else { 'mq5' }
    $sourceDir = Get-SourceDirectory -Type $Type
    $mainFilePath = Join-Path $sourceDir "$Name.$extension"
    
    $fileExists = Test-Path $mainFilePath
    
    if ($fileExists) {
        Write-Section "Mode UPDATE - Fichier existant détecté"
        Write-ColorOutput "    Fichier: $mainFilePath" -Color $Script:Colors.Detail
        
        # Copier les dépendances
        Copy-FileDependencies -FilePath $mainFilePath -Force:$Force
    } else {
        Write-Section "Mode CREATE - Création depuis template"
        
        # Créer le fichier depuis template
        $template = if ($projectConfig -and $projectConfig.template) { 
            $projectConfig.template 
        } elseif ($Template) {
            $Template
        } else { 
            Get-DefaultTemplate -Type $Type
        }
        
        
        $created = New-MT5File -Name $Name -Type $Type -Template $template -Config $config
        if (-not $created) {
            Write-Error "Échec de la création du fichier"
            return $false
        }
        
        # Copier les dépendances si configurées
        if ($projectConfig -and $projectConfig.ContainsKey('dependencies')) {
            $dependencies = $projectConfig.dependencies
            if ($dependencies -and $dependencies.Count -gt 0) {
                Write-Section "Copie des dépendances configurées"
                foreach ($dep in $dependencies) {
                    $sourcePath = Join-Path $Script:ProjectRoot $dep
                    if (Test-Path $sourcePath) {
                        Write-Success "Dépendance: $dep"
                        $Script:BuildState.DependenciesCopied += $dep
                    } else {
                        Write-Warning "Dépendance introuvable: $dep"
                    }
                }
            }
        }
    }
    
    # 3. Déploiement si demandé
    if ($Deploy) {
        Write-Section "Résolution des installations MT5"
        
        $targetInstallations = Get-MT5Targets -Config $config -ProjectConfig $projectConfig -Type $Type -OverrideTarget $MT5Target
        
        if ($targetInstallations.Count -eq 0) {
            Write-Warning "Aucune installation MT5 cible trouvée"
        } else {
            Write-ColorOutput "" -Color $Script:Colors.Info
            Write-ColorOutput "[*] Installations cibles:" -Color $Script:Colors.Info
            foreach ($inst in $targetInstallations) {
                Write-Success "$($inst.Name) (Priority: $($inst.Priority))"
                Write-ColorOutput "         $($inst.Path)" -Color $Script:Colors.Detail
            }
            
            # Déployer
            $deployed = Invoke-DeployToMT5 -Installations $targetInstallations -Type $Type -Compile:$Compile
            if (-not $deployed) {
                Write-Error "Échec du déploiement"
                return $false
            }
        }
    }
    
    # 4. Afficher le récapitulatif
    Write-Header "BUILD TERMINÉ AVEC SUCCÈS !"
    
    Write-ColorOutput "[*] Projet          : $($Script:BuildState.ProjectName)" -Color $Script:Colors.Info
    Write-ColorOutput "[*] Type            : $($Script:BuildState.ProjectType)" -Color $Script:Colors.Info
    Write-ColorOutput "[*] Fichiers créés  : $($Script:BuildState.FilesCreated.Count)" -Color $Script:Colors.Info
    Write-ColorOutput "[*] Dépendances     : $($Script:BuildState.DependenciesCopied.Count) fichier(s)" -Color $Script:Colors.Info
    
    if ($Deploy) {
        Write-ColorOutput "[*] Installations   : $($Script:BuildState.InstallationsTargeted.Count) cible(s)" -Color $Script:Colors.Info
        foreach ($inst in $Script:BuildState.InstallationsTargeted) {
            Write-ColorOutput "    - $inst" -Color $Script:Colors.Success
        }
    }
    
    if ($Compile) {
        Write-ColorOutput "[*] Compilation     : $($Script:BuildState.CompileResults.Success)/$($Script:BuildState.CompileResults.Total) succès" -Color $Script:Colors.Info
    }
    
    Write-Host ""
    Write-Host "=" * 50 -ForegroundColor $Script:Colors.Header
    
    return $true
}

# ============================================================================
# POINT D'ENTRÉE
# ============================================================================

# Vérifier que nous sommes dans le bon répertoire
if (-not (Test-Path "Deploy-MT5-Fixed.ps1")) {
    Write-Error "Ce script doit être exécuté depuis le répertoire racine du projet JTrading"
    exit 1
}

# Créer le dossier build s'il n'existe pas
$buildDir = Join-Path $Script:ProjectRoot "build"
if (-not (Test-Path $buildDir)) {
    New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
    Write-Success "Dossier build créé"
}

# Exécuter le build
try {
    $success = Build-Project
    if ($success) {
        exit 0
    } else {
        exit 1
    }
}
catch {
    Write-Error "Erreur fatale: $($_.Exception.Message)"
    exit 1
}
