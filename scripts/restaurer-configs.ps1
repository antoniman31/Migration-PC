<#
.SYNOPSIS
    Remet en place les dossiers de configuration sauvegardes par
    sauvegarder-configs.ps1.

.DESCRIPTION
    C'est le seul script du projet qui ECRIT sur votre disque. Il est donc
    prudent par defaut, et il vaut mieux qu'il refuse trop que trop peu :

      - il ne restaure QUE ce que l'index decrit, jamais un chemin devine ;
      - il REFUSE d'ecraser un dossier existant, sauf -Remplacer ;
      - avec -Remplacer, il met d'abord l'existant de cote dans un dossier
        date, pour que l'operation reste annulable ;
      - -Simuler montre tout ce qui se passerait sans rien ecrire.

    A lancer APRES avoir installe les logiciels : la plupart creent leur
    dossier de reglages au premier demarrage, et l'ecraser ensuite est plus
    sur que de le precer.

.PARAMETER Source
    Le dossier produit par sauvegarder-configs.ps1, contenant index-configs.json.

.PARAMETER Remplacer
    Autorise l'ecrasement d'un dossier existant. L'ancien est mis de cote.

.PARAMETER Simuler
    Montre ce qui serait fait, sans rien ecrire. A faire au moins une fois.

.EXAMPLE
    .\restaurer-configs.ps1 -Source E:\migration\configs -Simuler
    .\restaurer-configs.ps1 -Source E:\migration\configs

.NOTES
    Windows. PowerShell 5.1 ou superieur.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Source,
    [switch]$Remplacer,
    [switch]$Simuler
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
# La console de Windows n'ecrit pas en UTF-8 par defaut : les accents de ce
# script y arriveraient en charabia. Les .bat font un « chcp 65001 », mais on
# peut aussi lancer ce fichier directement, et sous Windows PowerShell 5.1
# chcp ne suffit pas toujours. On le fixe ici, sans rien casser si l'hote
# refuse (redirection, console absente).
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch { }

function Test-DossierVide {
    param([string]$Chemin)
    if (-not (Test-Path -LiteralPath $Chemin)) { return $true }
    $item = Get-Item -LiteralPath $Chemin -Force
    if (-not $item.PSIsContainer) { return $false }
    return (@(Get-ChildItem -LiteralPath $Chemin -Force -ErrorAction SilentlyContinue).Count -eq 0)
}

if (-not (Test-Path -LiteralPath $Source)) {
    Write-Error "Dossier introuvable : $Source"
    exit 1
}
$fichierIndex = Join-Path $Source 'index-configs.json'
if (-not (Test-Path -LiteralPath $fichierIndex)) {
    Write-Error "index-configs.json est introuvable dans $Source. Ce dossier n'a pas ete produit par sauvegarder-configs.ps1."
    exit 1
}

$index = Get-Content -LiteralPath $fichierIndex -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $index.PSObject.Properties['entrees']) {
    Write-Error "index-configs.json ne contient pas de liste d'entrees."
    exit 1
}
$entrees = @($index.entrees)

Write-Host ""
Write-Host "Restauration des configurations" -ForegroundColor Cyan
Write-Host "-------------------------------"
Write-Host ("  sauvegarde du {0}, machine {1}" -f
    $(if ($index.PSObject.Properties['genere']) { ([string]$index.genere).Substring(0,10) } else { '?' }),
    $(if ($index.PSObject.Properties['machine']) { $index.machine } else { '?' }))
Write-Host ("  {0} entree(s)" -f @($entrees).Count)
if ($Simuler) { Write-Host "  MODE SIMULATION : rien ne sera ecrit" -ForegroundColor Cyan }
Write-Host ""

$horodatage = (Get-Date).ToString('yyyyMMdd-HHmmss')
$faits = 0; $sautes = 0; $echecs = 0

# Ou reposer une entree, sur CETTE machine.
#
# L'index garde deux choses : « origine », le chemin tel qu'il etait sur
# l'ancien PC, et « modele », le meme avant expansion des variables. Le
# premier porte le nom d'utilisateur de l'ancienne machine. Restaurer dessus
# creait C:\Users\<ancien nom>\... sur le PC neuf — un dossier que personne
# ne lit, sous un profil qui n'existe pas — et l'annoncait en vert.
#
# Le modele, lui, se deroule ici : %APPDATA% vaut ce qu'il vaut sur cette
# machine. On ne retombe sur l'origine que pour un index ancien, qui n'a pas
# de modele, ou si une variable ne se resout pas.
function Get-Destination {
    param($Entree)
    $modele = ''
    if ($Entree.PSObject.Properties['modele']) { $modele = [string]$Entree.modele }
    if ($modele) {
        $deroule = [Environment]::ExpandEnvironmentVariables($modele)
        if ($deroule -notlike '*%*') { return $deroule }
    }
    return [string]$Entree.origine
}

foreach ($e in $entrees) {
    $nom = [string]$e.nom
    $vers = Get-Destination -Entree $e
    $origine = [string]$e.origine
    if ($vers -ne $origine) {
        Write-Host ("  ailleurs {0,-27} {1}" -f $nom, $vers) -ForegroundColor DarkGray
        Write-Host ("           (sur l'ancien PC : $origine)") -ForegroundColor DarkGray
    }
    $depuis = Join-Path $Source ([string]$e.dossier)

    if (-not (Test-Path -LiteralPath $depuis)) {
        Write-Host ("  absent  {0,-28} la copie ne contient pas ce dossier" -f $nom) -ForegroundColor Yellow
        $sautes++
        continue
    }

    $occupe = -not (Test-DossierVide -Chemin $vers)
    if ($occupe -and -not $Remplacer) {
        Write-Host ("  refuse  {0,-28} existe deja : {1}" -f $nom, $vers) -ForegroundColor Yellow
        Write-Host ("          -Remplacer pour l'ecraser (l'ancien sera mis de cote)")
        $sautes++
        continue
    }

    if ($Simuler) {
        $quoi = if ($occupe) { "REMPLACERAIT (ancien mis de cote)" } else { "poserait" }
        Write-Host ("  {0,-34} {1,-28} -> {2}" -f $quoi, $nom, $vers)
        continue
    }

    try {
        if ($occupe) {
            # L'operation doit rester annulable : on deplace avant d'ecrire.
            $misDeCote = "$vers.avant-migration-$horodatage"
            Move-Item -LiteralPath $vers -Destination $misDeCote -Force -ErrorAction Stop
            Write-Host ("  ancien  {0,-28} mis de cote : {1}" -f $nom, (Split-Path $misDeCote -Leaf)) -ForegroundColor DarkGray
        }
        $parent = Split-Path $vers -Parent
        if ($parent -and -not (Test-Path -LiteralPath $parent)) {
            $null = New-Item -ItemType Directory -Path $parent -Force
        }
        # Le contenu du dossier sauvegarde, pas le dossier lui-meme : sinon on
        # obtiendrait Code\User\User.
        $interieur = @(Get-ChildItem -LiteralPath $depuis -Force)
        if ($interieur.Count -eq 1 -and $interieur[0].PSIsContainer -and
            $interieur[0].Name -eq (Split-Path $vers -Leaf)) {
            Copy-Item -LiteralPath $interieur[0].FullName -Destination $vers -Recurse -Force -ErrorAction Stop
        } else {
            $null = New-Item -ItemType Directory -Path $vers -Force
            foreach ($item in $interieur) {
                Copy-Item -LiteralPath $item.FullName -Destination $vers -Recurse -Force -ErrorAction Stop
            }
        }
        Write-Host ("  pose    {0,-28} -> {1}" -f $nom, $vers) -ForegroundColor Green
        $faits++
    } catch {
        Write-Host ("  echec   {0,-28} {1}" -f $nom, $_.Exception.Message) -ForegroundColor Red
        $echecs++
    }
}

Write-Host ""
if ($Simuler) {
    Write-Host "Simulation terminee : rien n'a ete ecrit." -ForegroundColor Cyan
    Write-Host "Relancez sans -Simuler pour appliquer."
} else {
    Write-Host "$faits restaure(s), $sautes saute(s)$(if ($echecs) { ", $echecs echec(s)" })." -ForegroundColor Green
    if ($faits) {
        Write-Host ""
        Write-Host "Fermez et rouvrez les logiciels concernes : la plupart lisent leurs"
        Write-Host "reglages au demarrage et reecriraient par-dessus en se fermant."
    }
}
Write-Host ""
