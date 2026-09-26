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
# La console de Windows n'ecrit pas en UTF-8 par defaut : les accents de ce
# script y arriveraient en charabia. Les .bat font un « chcp 65001 », mais on
# peut aussi lancer ce fichier directement, et sous Windows PowerShell 5.1
# chcp ne suffit pas toujours. On le fixe ici, sans rien casser si l'hote
# refuse (redirection, console absente).
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch { }

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

# Un navigateur ouvert verrouille ses marque-pages et ses mots de passe : la
# copie echouait fichier par fichier, noye au milieu du reste, et personne ne
# faisait le lien avec Firefox reste ouvert derriere. On le dit avant, pas
# apres — et on ne ferme rien a la place de l'utilisateur.
$aFermer = @(Get-LogicielsAFermer -NomsConfigs @($configs | ForEach-Object { $_.nom }))
if ($aFermer.Count) {
    Write-Host ""
    Write-Host "Ferme ces logiciels avant de continuer :" -ForegroundColor Yellow
    foreach ($l in $aFermer) { Write-Host "  - $l" -ForegroundColor Yellow }
    Write-Host "  Ouverts, ils verrouillent leurs propres fichiers — marque-pages, mots de"
    Write-Host "  passe, cookies. Ce sont justement ceux qu'on vient chercher."
    if (-not $Simuler) {
        Write-Host ""
        $rep = Read-Host "  Continuer quand meme ? (o/N)"
        if ($rep -notmatch '^(o|O|y|Y)') {
            Write-Host "  Interrompu. Ferme-les et relance."
            exit 0
        }
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
        $quoiCopie = if ($c.Contains('registre') -and $c.registre) { 'registre' } else { $taille }
        Write-Host ("  [simulation] {0,-28} {1,10}  <- {2}" -f $c.nom, $quoiCopie, $c.chemin)
        continue
    }

    $exclure = @()
    if ($c.Contains('exclure') -and $c.exclure) { $exclure = @($c.exclure) }

    # Une cle de registre ne se copie pas, elle s'exporte. PuTTY range ses
    # sessions SSH entieres la, 7-Zip et WinRAR leurs reglages : sans cette
    # branche ils partaient en silence, parce que rien n'echouait — la table
    # ne les decrivait simplement pas.
    if ($c.Contains('registre') -and $c.registre) {
        try {
            $null = New-Item -ItemType Directory -Path $cible -Force
            $fichierReg = Join-Path $cible ($sousDossier + '.reg')
            # reg.exe veut la forme « HKCU\... », pas le lecteur PowerShell
            # « HKCU:\... » : le deux-points fait echouer l'export sans que
            # reg.exe explique pourquoi.
            $pourReg = ($c.chemin -replace '^([A-Z_]+):', '$1')
            $sortie = & reg.exe export $pourReg $fichierReg /y 2>&1
            if ($LASTEXITCODE -ne 0) { throw "reg export a echoue : $sortie" }
            Write-Host ("  export  {0,-28} {1,10}" -f $c.nom, 'registre') -ForegroundColor Green
            $copies++
            $index += [ordered]@{
                nom      = $c.nom
                origine  = $c.chemin
                modele   = if ($c.Contains('modele')) { $c.modele } else { $c.chemin }
                dossier  = $sousDossier
                quoi     = $c.quoi
                exclu    = @()
                tailleMo = $null
                # La restauration lit ce marqueur pour reimporter au lieu de
                # recopier des fichiers.
                registre = $true
                fichier  = ($sousDossier + '.reg')
            }
        } catch {
            Write-Host ("  echec   {0,-28} {1}" -f $c.nom, $_.Exception.Message) -ForegroundColor Yellow
            $echecs++
        }
        continue
    }

    try {
        $source = Get-Item -LiteralPath $c.chemin -Force -ErrorAction Stop
        $null = New-Item -ItemType Directory -Path $cible -Force
        if (-not $source.PSIsContainer) {
            Copy-Item -LiteralPath $c.chemin -Destination $cible -Force -ErrorAction Stop
        }
        elseif ($exclure.Count -eq 0) {
            # Le CONTENU dans le dossier nomme, pas le dossier sous son nom
            # d'origine : l'index designe « Cles SSH », et la restauration ira
            # chercher ce nom-la. Copy-Item -Destination <dossier> aurait cree
            # « .ssh » dedans, que l'index ne decrit pas.
            foreach ($item in @(Get-ChildItem -LiteralPath $c.chemin -Force)) {
                Copy-Item -LiteralPath $item.FullName -Destination $cible -Recurse -Force -ErrorAction Stop
            }
        }
        else {
            # Copy-Item -Recurse ne sait rien laisser derriere lui : des qu'une
            # regle exclut quelque chose, on recopie fichier par fichier, sur la
            # meme liste que celle qui a servi a annoncer la taille. Plus lent,
            # mais c'est le prix pour ne pas emporter dix Go de caches.
            $racine = $source.FullName.TrimEnd('\', '/')
            foreach ($f in @(Get-FichiersRetenus -Racine $c.chemin -Exclure $exclure)) {
                $rel = $f.FullName.Substring($racine.Length).TrimStart('\', '/')
                $vers = Join-Path $cible $rel
                $parent = Split-Path $vers -Parent
                if ($parent -and -not (Test-Path -LiteralPath $parent)) {
                    $null = New-Item -ItemType Directory -Path $parent -Force
                }
                Copy-Item -LiteralPath $f.FullName -Destination $vers -Force -ErrorAction Stop
            }
        }
        Write-Host ("  copie   {0,-28} {1,10}" -f $c.nom, $taille) -ForegroundColor Green
        $copies++
        $index += [ordered]@{
            nom      = $c.nom
            origine  = $c.chemin
            # Le chemin encore variabilise : c'est lui que la restauration
            # deroulera sur la machine d'arrivee, dont le nom d'utilisateur
            # n'est pas forcement le meme.
            modele   = if ($c.Contains('modele')) { $c.modele } else { '' }
            dossier  = $sousDossier
            quoi     = $c.quoi
            # Ce qui a ete laisse derriere : sans cette trace, une copie
            # partielle ressemblerait a une copie complete qui aurait perdu
            # des fichiers en route.
            exclu    = $exclure
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
Write-TexteUtf8 -Chemin ([System.IO.Path]::GetFullPath($fichierIndex)) -Contenu ($contenu | ConvertTo-Json -Depth 6)

Write-Host ""
Write-Host "$copies dossier(s) copie(s)$(if ($echecs) { ", $echecs echec(s)" })." -ForegroundColor Green
Write-Host "Index ecrit : $fichierIndex"
Write-Host ""
Write-Host "Sur le nouveau PC, apres avoir installe les logiciels :"
# Le chemin est recopie par l'utilisateur dans une console : s'il contient
# une espace, la commande suggeree doit deja porter ses guillemets.
$aRecopier = if ($Destination -match '\s') { '"' + $Destination + '"' } else { $Destination }
Write-Host "  .\restaurer-configs.ps1 -Source $aRecopier"
Write-Host ""
