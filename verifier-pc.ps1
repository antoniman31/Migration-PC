<#
.SYNOPSIS
    Constate ce qui est deja installe sur le NOUVEAU PC et propose de cocher
    les taches correspondantes dans la checklist.

.DESCRIPTION
    scan-pc.ps1 inventorie la machine qu'on quitte. Ce script fait l'inverse :
    lance sur la machine qu'on installe, il detecte ce qui est deja en place et
    le rapproche des elements du profil, pour eviter de cocher a la main des
    dizaines de cases deja acquises.

    Il ne coche rien lui-meme : il ecrit un fichier de propositions que la page
    affiche pour validation. Chaque correspondance porte sa raison, afin de
    pouvoir juger sur piece :
      - identifiant winget identique : fiable ;
      - nom normalise identique : a verifier, deux logiciels peuvent porter
        des noms voisins.

    Aucune donnee ne quitte la machine : le script n'ecrit qu'un fichier local.

.PARAMETER Profil
    Le profil JSON dont il faut verifier les elements. Par defaut, cherche a
    cote du script, dans cet ordre : profil-local.json,
    profil-migration-pc.json (le nom sous lequel la page exporte un profil),
    puis presets/exemple.json.

.PARAMETER Sortie
    Fichier produit. Par defaut verification-pc.json.

.PARAMETER NomsApproximatifs
    Accepte aussi les rapprochements par nom seul. Sans cette option, seuls les
    identifiants winget sont retenus : moins de correspondances, aucune fausse.

.PARAMETER SansJeux
    Ignore les bibliotheques de jeux.

.EXAMPLE
    .\verifier-pc.ps1
    Scan standard, ecrit .\verification-pc.json

.EXAMPLE
    .\verifier-pc.ps1 -Profil D:\migration\mon-profil.json -NomsApproximatifs

.NOTES
    Windows uniquement. PowerShell 5.1 ou superieur.
    Necessite lib-detection.ps1 a cote de ce script.
    Si l'execution est bloquee :
        powershell -ExecutionPolicy Bypass -File .\verifier-pc.ps1
#>

[CmdletBinding()]
param(
    [switch]$PasDOuverture,
    [string]$Profil,
    [string]$Sortie = "verification-pc.json",
    [switch]$NomsApproximatifs,
    [switch]$SansJeux,
    [switch]$ToutInclure
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$lib = Join-Path $PSScriptRoot 'lib-detection.ps1'
if (-not (Test-Path $lib)) {
    Write-Error "lib-detection.ps1 est introuvable a cote de ce script. Copiez les deux fichiers ensemble."
    exit 1
}
$resultats = @{}
. $lib

# Ecriture du resultat a cote de la page, et ouverture du navigateur.
$aide = Join-Path $PSScriptRoot 'ecrire-resultat.ps1'
if (Test-Path $aide) { . $aide }

# ---------------------------------------------------------------- profil

function Find-Profil {
    if ($Profil) {
        if (-not (Test-Path $Profil)) { throw "Profil introuvable : $Profil" }
        return $Profil
    }
    # Le profil personnel prime sur l'exemple : c'est celui qu'on veut verifier.
    # profil-migration-pc.json est le nom que la page donne a son export : sans
    # lui, exporter son profil puis le poser a cote du script ne suffisait pas.
    foreach ($c in @('profil-local.json', 'profil-migration-pc.json', 'presets\exemple.json')) {
        $p = Join-Path $PSScriptRoot $c
        if (Test-Path $p) { return $p }
    }
    throw "Aucun profil trouve. Passez -Profil <chemin>."
}

$cheminProfil = Find-Profil
Write-Host ""
Write-Host "Verification du nouveau PC" -ForegroundColor Cyan
Write-Host "--------------------------"
Write-Host "  profil : $(Split-Path $cheminProfil -Leaf)"

$donnees = Get-Content $cheminProfil -Raw -Encoding UTF8 | ConvertFrom-Json

# Seuls les onglets « Nouveau PC » et « Apps » designent des logiciels
# installables. Les sauvegardes et les raccourcis relevent d'autre chose :
# verifier-sauvegardes.ps1 pour les premieres, l'oeil pour les seconds.
$aVerifier = @()
foreach ($section in @('npc', 'apps')) {
    if ($donnees.PSObject.Properties[$section]) {
        foreach ($e in $donnees.$section) { $aVerifier += $e }
    }
}
Write-Host "  elements verifiables : $(@($aVerifier).Count)"
Write-Host ""

# ---------------------------------------------------------------- detection

Write-Host "Detection des logiciels presents" -ForegroundColor Cyan
$null = Invoke-Detecteur -Nom 'Winget' -Bloc { Read-Winget }
$null = Invoke-Detecteur -Nom 'Registre' -Bloc { Read-Registre }
$null = Invoke-Detecteur -Nom 'Store' -Bloc { Read-Store }
if (-not $SansJeux) {
    $null = Invoke-Detecteur -Nom 'Steam' -Bloc { Read-Steam }
    $null = Invoke-Detecteur -Nom 'Epic' -Bloc { Read-Epic }
    $null = Invoke-Detecteur -Nom 'GOG' -Bloc { Read-GOG }
    $null = Invoke-Detecteur -Nom 'Ubisoft Connect' -Bloc { Read-Ubisoft }
    $null = Invoke-Detecteur -Nom 'EA App' -Bloc { Read-Ea }
    $null = Invoke-Detecteur -Nom 'Xbox' -Bloc { Read-Xbox }
}
$installes = @($resultats.Values)
Write-Host ""

# ---------------------------------------------------------------- rapprochement

# Un profil ecrit a la main peut omettre un champ. Sous Set-StrictMode, lire
# une propriete absente est une erreur fatale : tout le script s'arretait sur
# un seul element incomplet. Trouve en executant le script sur un profil sans
# champ « p ».
function Get-Champ {
    param($Objet, [string]$Nom, $Defaut = '')
    if ($null -eq $Objet) { return $Defaut }
    if (-not $Objet.PSObject.Properties[$Nom]) { return $Defaut }
    $v = $Objet.$Nom
    if ($null -eq $v) { return $Defaut }
    return $v
}

# Deux index, du plus fiable au moins fiable.
$parWinget = @{}
$parCle    = @{}
foreach ($a in $installes) {
    if ($a.winget) {
        $k = $a.winget.ToLowerInvariant()
        if (-not $parWinget.ContainsKey($k)) { $parWinget[$k] = $a }
    }
    $c = Get-Cle -Nom $a.nom
    if ($c -and -not $parCle.ContainsKey($c)) { $parCle[$c] = $a }
}

$trouves   = @()
$absents   = @()

foreach ($e in $aVerifier) {
    $id  = [string](Get-Champ $e 'id')
    $nom = [string](Get-Champ $e 'n' 'Element sans nom')

    $correspondance = $null
    $raison = ''
    $confiance = ''

    # 1. identifiant winget : deux paquets de meme identifiant sont le meme paquet.
    $w = Get-Champ $e 'w' $null
    if ($w) {
        $k = ([string]$w).ToLowerInvariant()
        if ($parWinget.ContainsKey($k)) {
            $correspondance = $parWinget[$k]
            $raison = "identifiant winget $w"
            $confiance = 'sure'
        }
    }

    # 2. nom normalise : utile, mais « Python » ne dit pas quelle version.
    if (-not $correspondance -and $NomsApproximatifs) {
        $c = Get-Cle -Nom $nom
        if ($c -and $parCle.ContainsKey($c)) {
            $correspondance = $parCle[$c]
            $raison = "nom correspondant a « $($parCle[$c].nom) »"
            $confiance = 'approximative'
        }
    }

    if ($correspondance) {
        $trouves += [ordered]@{
            id        = $id
            nom       = $nom
            detecte   = $correspondance.nom
            version   = $correspondance.version
            source    = $correspondance.source
            raison    = $raison
            confiance = $confiance
        }
    } else {
        $absents += [ordered]@{ id = $id; nom = $nom }
    }
}

# ---------------------------------------------------------------- sortie

# try/catch et if ne sont pas des expressions utilisables dans un hashtable
# en PowerShell 5.1 : on calcule d'abord.
$os = try { (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).Caption } catch { 'Windows' }
$nomProfil = ''
if ($donnees.PSObject.Properties['meta'] -and $donnees.meta.PSObject.Properties['nom']) {
    $nomProfil = $donnees.meta.nom
}

# Sur une machine neuve, ce qui compte n'est pas seulement ce qui est installe,
# c'est ce que Windows signale comme mal installe. Ce n'est pas une deduction :
# c'est ce que le gestionnaire de peripheriques affiche avec un point
# d'exclamation.
$materiel = Invoke-Detecteur -Nom 'materiel' -Bloc { Read-Materiel }
$pilotes  = @(Invoke-Detecteur -Nom 'pilotes' -Bloc { Read-PilotesManquants })

$verification = [ordered]@{
    type    = 'verification-migration-pc'
    version = 1
    genere  = (Get-Date).ToString('o')
    machine = [ordered]@{
        os  = $os
        nom = $env:COMPUTERNAME
    }
    profil  = [ordered]@{
        fichier = (Split-Path $cheminProfil -Leaf)
        nom     = $nomProfil
    }
    trouves  = @($trouves)
    materiel = $materiel
    pilotes  = @($pilotes)
    absents = @($absents)
}

Set-Content -Path $Sortie -Value ($verification | ConvertTo-Json -Depth 6) -Encoding UTF8

if (Get-Command Write-ResultatPourSite -ErrorAction SilentlyContinue) {
    Write-ResultatPourSite -Donnees $verification -DossierScript $PSScriptRoot -NePasOuvrir:$PasDOuverture
}
$chemin = (Resolve-Path $Sortie).Path

$sures = @($trouves | Where-Object { $_.confiance -eq 'sure' }).Count
$approx = @($trouves).Count - $sures

Write-Host "$(@($trouves).Count) element(s) deja en place sur $(@($aVerifier).Count)." -ForegroundColor Green
if ($sures -gt 0)  { Write-Host "  dont $sures par identifiant winget (fiable)" }
if ($approx -gt 0) { Write-Host "  dont $approx par nom seul, a verifier" -ForegroundColor Yellow }
if (-not $NomsApproximatifs) {
    Write-Host "  (-NomsApproximatifs elargit la recherche aux noms, avec un risque de faux positif)"
}
if (@($pilotes).Count) {
    Write-Host ""
    Write-Host "$(@($pilotes).Count) peripherique(s) sans pilote utilisable :" -ForegroundColor Yellow
    foreach ($p in $pilotes) {
        Write-Host ("  - {0} ({1})" -f $p.nom, $p.probleme)
    }
    Write-Host "  Le site vous indiquera ou chercher, a partir du materiel detecte."
}
Write-Host "Fichier ecrit : $chemin"
Write-Host ""
Write-Host "Etape suivante : ouvrir index.html, cliquer sur Importer, choisir ce fichier."
Write-Host "La page affichera la liste et vous demandera de confirmer avant de cocher."
Write-Host ""
