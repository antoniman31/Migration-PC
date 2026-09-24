<#
.SYNOPSIS
    Copie les dossiers de configuration reperes vers un dossier de sauvegarde.

.DESCRIPTION
    Le scan sait ou vivent les reglages de vos logiciels. Ce script les copie,
    avec un index de ce qui a ete pris et d'ou ca venait — c'est cet index qui
    permettra de les remettre en place plus tard, sans deviner.

    Il ne touche a rien sur la machine : il lit et il copie.

.PARAMETER Destination
    Le dossier ou deposer la copie. Cree s'il n'existe pas.

.PARAMETER Simuler
    Affiche ce qui serait copie, sans rien ecrire.

.EXAMPLE
    .\sauvegarder-configs.ps1 -Destination E:\migration\configs

.NOTES
    Windows. PowerShell 5.1 ou superieur.
    Necessite lib-detection.ps1 a cote de ce script.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Destination,
    [switch]$Simuler,
    [switch]$ToutInclure
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$lib = Join-Path $PSScriptRoot 'lib-detection.ps1'
if (-not (Test-Path $lib)) {
    Write-Error "lib-detection.ps1 est introuvable a cote de ce script. Copiez le dossier entier."
    exit 1
}
$resultats = @{}
. $lib

Write-Host ""
Write-Host "Sauvegarde des configurations" -ForegroundColor Cyan
Write-Host "-----------------------------"

# On a besoin de savoir ce qui est installe : une regle rattachee a un logiciel
# absent ne s'applique pas.
$null = Invoke-Detecteur -Nom 'winget'   -Bloc { Read-Winget }
$null = Invoke-Detecteur -Nom 'registre' -Bloc { Read-Registre }
$null = Invoke-Detecteur -Nom 'Store'    -Bloc { Read-Store }
$configs = @(Invoke-Detecteur -Nom 'configurations' -Bloc {
    Read-Configs -ClesInstallees @($resultats.Keys)
})

if (@($configs).Count -eq 0) {
    Write-Host ""
    Write-Host "Aucun dossier de configuration connu n'a ete trouve." -ForegroundColor Yellow
    Write-Host "Ce n'est pas une erreur : la table ne couvre qu'une trentaine de logiciels."
    exit 0
}

if (-not $Simuler) {
    if (-not (Test-Path -LiteralPath $Destination)) {
        $null = New-Item -ItemType Directory -Path $Destination -Force
    }
}

Write-Host ""
$index = @()
$copies = 0
$echecs = 0
foreach ($c in $configs) {
    # Un nom de dossier sur par entree : deux logiciels peuvent porter le meme
    # nom de dossier de reglages a des endroits differents.
    $sousDossier = ($c.nom -replace '[^\w\- ]', '_').Trim()
    $cible = Join-Path $Destination $sousDossier
    $taille = if ($c.tailleMo) { "{0} Mo" -f [math]::Round($c.tailleMo, 0) } else { "vide" }

    if ($Simuler) {
        Write-Host ("  [simulation] {0,-28} {1,10}  <- {2}" -f $c.nom, $taille, $c.chemin)
        continue
    }

    try {
        $source = Get-Item -LiteralPath $c.chemin -Force -ErrorAction Stop
        $null = New-Item -ItemType Directory -Path $cible -Force
        if ($source.PSIsContainer) {
            # Le CONTENU dans le dossier nomme, pas le dossier sous son nom
            # d'origine : l'index designe « Cles SSH », et la restauration ira
            # chercher ce nom-la. Copy-Item -Destination <dossier> aurait cree
            # « .ssh » dedans, que l'index ne decrit pas.
            foreach ($item in @(Get-ChildItem -LiteralPath $c.chemin -Force)) {
                Copy-Item -LiteralPath $item.FullName -Destination $cible -Recurse -Force -ErrorAction Stop
            }
        } else {
            Copy-Item -LiteralPath $c.chemin -Destination $cible -Force -ErrorAction Stop
        }
        Write-Host ("  copie   {0,-28} {1,10}" -f $c.nom, $taille) -ForegroundColor Green
        $copies++
        $index += [ordered]@{
            nom      = $c.nom
            origine  = $c.chemin
            dossier  = $sousDossier
            quoi     = $c.quoi
            tailleMo = $c.tailleMo
        }
    } catch {
        Write-Host ("  echec   {0,-28} {1}" -f $c.nom, $_.Exception.Message) -ForegroundColor Yellow
        $echecs++
    }
}

if ($Simuler) {
    Write-Host ""
    Write-Host "Simulation : rien n'a ete ecrit. Relancez sans -Simuler pour copier."
    exit 0
}

# L'index dit d'ou venait chaque dossier. Sans lui, restaurer reviendrait a
# deviner, et deviner un chemin de configuration se paie cher.
$fichierIndex = Join-Path $Destination 'index-configs.json'
$contenu = [ordered]@{
    type    = 'configs-migration-pc'
    version = 1
    genere  = (Get-Date).ToString('o')
    machine = $env:COMPUTERNAME
    entrees = @($index)
}
Set-Content -LiteralPath $fichierIndex -Value ($contenu | ConvertTo-Json -Depth 6) -Encoding UTF8

Write-Host ""
Write-Host "$copies dossier(s) copie(s)$(if ($echecs) { ", $echecs echec(s)" })." -ForegroundColor Green
Write-Host "Index ecrit : $fichierIndex"
Write-Host ""
Write-Host "Sur le nouveau PC, apres avoir installe les logiciels :"
Write-Host "  .\restaurer-configs.ps1 -Source $Destination"
Write-Host ""
