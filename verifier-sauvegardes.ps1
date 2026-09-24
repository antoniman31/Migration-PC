<#
.SYNOPSIS
    Compare les dossiers a sauvegarder avec leur copie, et dit ce qui manque.

.DESCRIPTION
    L'onglet « Donnees » de la checklist liste des chemins, et on coche en
    confiance. Ce script transforme cette declaration d'intention en
    verification : pour chaque element du profil qui designe un vrai dossier,
    il compte les fichiers et mesure la taille des deux cotes, puis signale
    les ecarts.

    Tous les elements ne sont pas verifiables : « Courriels et espaces
    clients » ou « Parametres > Bluetooth » ne designent aucun dossier. Ils
    sont rapportes comme tels plutot que passes sous silence.

    Un element peut porter plusieurs chemins, separes par une virgule ou par
    « et » : ils sont traites un par un.

    Le script ne modifie rien : il lit les deux cotes et ecrit un rapport.

.PARAMETER Destination
    Le dossier ou la sauvegarde a ete faite. Obligatoire. Chaque element y est
    cherche dans un sous-dossier portant son identifiant, puis, a defaut, par
    le nom du dossier source.

.PARAMETER Profil
    Le profil JSON. Par defaut, cherche a cote du script, dans cet ordre :
    profil-local.json, profil-migration-pc.json (le nom sous lequel la page
    exporte un profil), puis presets/exemple.json.

.PARAMETER Sortie
    Rapport produit. Par defaut verification-sauvegardes.json.

.PARAMETER ToleranceParCent
    Ecart de taille tolere avant de signaler un probleme. 2 % par defaut : une
    copie ne rend jamais exactement le meme total a l'octet pres.

.EXAMPLE
    .\verifier-sauvegardes.ps1 -Destination D:\sauvegarde-migration

.EXAMPLE
    .\verifier-sauvegardes.ps1 -Destination E:\backup -Profil mon-profil.json

.NOTES
    Windows uniquement. PowerShell 5.1 ou superieur.
    Parcourir de gros dossiers prend du temps : le script affiche sa
    progression element par element.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Destination,
    [string]$Profil,
    [string]$Sortie = "verification-sauvegardes.json",
    [double]$ToleranceParCent = 2
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# ---------------------------------------------------------------- chemins

# Un champ « chemin » du profil peut en contenir plusieurs, ou n'etre qu'une
# indication en francais. On ne garde que ce qui ressemble vraiment a un chemin.
function Split-Chemins {
    param([string]$Texte)
    if ([string]::IsNullOrWhiteSpace($Texte)) { return @() }
    $morceaux = $Texte -split '\s+et\s+|,\s*'
    $sortie = @()
    foreach ($m in $morceaux) {
        $m = $m.Trim()
        if (-not $m) { continue }
        # Une lettre de lecteur, un chemin UNC, ou une variable d'environnement.
        if ($m -match '^[A-Za-z]:\\' -or $m -match '^\\\\' -or $m -match '%[^%]+%') {
            $sortie += $m
        }
    }
    return $sortie
}

function Expand-Chemin {
    param([string]$Chemin)
    return [Environment]::ExpandEnvironmentVariables($Chemin)
}

# Nombre de fichiers et octets d'un dossier, ou d'un fichier seul.
function Measure-Contenu {
    param([string]$Chemin)
    if (-not (Test-Path -LiteralPath $Chemin)) {
        return [ordered]@{ existe = $false; fichiers = 0; octets = 0 }
    }
    $item = Get-Item -LiteralPath $Chemin -Force -ErrorAction SilentlyContinue
    if ($item -and -not $item.PSIsContainer) {
        return [ordered]@{ existe = $true; fichiers = 1; octets = [int64]$item.Length }
    }
    $n = 0; $o = [int64]0
    # -ErrorAction SilentlyContinue : un dossier protege ne doit pas arreter
    # le parcours, il fausse seulement son propre compte.
    Get-ChildItem -LiteralPath $Chemin -Recurse -File -Force -ErrorAction SilentlyContinue |
        ForEach-Object { $n++; $o += $_.Length }
    return [ordered]@{ existe = $true; fichiers = $n; octets = $o }
}

function Format-Taille {
    param([int64]$Octets)
    if ($Octets -ge 1GB) { return "{0:N1} Go" -f ($Octets / 1GB) }
    if ($Octets -ge 1MB) { return "{0:N0} Mo" -f ($Octets / 1MB) }
    if ($Octets -ge 1KB) { return "{0:N0} Ko" -f ($Octets / 1KB) }
    return "$Octets o"
}

# ---------------------------------------------------------------- profil

function Find-Profil {
    if ($Profil) {
        if (-not (Test-Path $Profil)) { throw "Profil introuvable : $Profil" }
        return $Profil
    }
    # profil-migration-pc.json est le nom que la page donne a son export : sans
    # lui, exporter son profil puis le poser a cote du script ne suffisait pas.
    foreach ($c in @('profil-local.json', 'profil-migration-pc.json', 'presets\exemple.json')) {
        $p = Join-Path $PSScriptRoot $c
        if (Test-Path $p) { return $p }
    }
    throw "Aucun profil trouve. Passez -Profil <chemin>."
}

if (-not (Test-Path -LiteralPath $Destination)) {
    Write-Error "Destination introuvable : $Destination"
    exit 1
}

$cheminProfil = Find-Profil
$donnees = Get-Content $cheminProfil -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $donnees.PSObject.Properties['data']) {
    Write-Error "Ce profil n'a pas d'onglet 'data'."
    exit 1
}

Write-Host ""
Write-Host "Verification des sauvegardes" -ForegroundColor Cyan
Write-Host "----------------------------"
Write-Host "  profil      : $(Split-Path $cheminProfil -Leaf)"
Write-Host "  destination : $Destination"
Write-Host ""

# ---------------------------------------------------------------- comparaison

$resultatsVerif = @()

foreach ($e in $donnees.data) {
    $nom = $e.n
    $chemins = Split-Chemins -Texte $e.p

    # @() : PowerShell aplatit un tableau d'un seul element, et .Count
    # echoue alors sous Set-StrictMode. Trouve en executant le script.
    if (-not @($chemins).Count) {
        Write-Host "  ~ $nom" -ForegroundColor DarkGray
        Write-Host "      ne designe pas un dossier : a verifier a la main" -ForegroundColor DarkGray
        $resultatsVerif += [ordered]@{
            id = $e.id; nom = $nom; etat = 'non-verifiable'
            detail = "« $($e.p) » ne designe pas un chemin"
            chemins = @()
        }
        continue
    }

    Write-Host "  . $nom" -NoNewline
    $details = @()
    $etatGlobal = 'ok'

    foreach ($c in $chemins) {
        $source = Expand-Chemin -Chemin $c
        $src = Measure-Contenu -Chemin $source

        # Rien a sauvegarder : la source n'existe pas, ou elle est vide. Dans
        # les deux cas l'absence de copie n'est pas une faute, et le signaler
        # noierait les vrais problemes.
        if (-not $src.existe -or $src.fichiers -eq 0) {
            $details += [ordered]@{
                chemin = $c; source = $source; etat = 'source-absente'
                fichiersSource = 0; fichiersCopie = 0; octetsSource = 0; octetsCopie = 0
            }
            continue
        }

        # On cherche la copie par identifiant, puis par nom de dossier source.
        $candidats = @(
            (Join-Path $Destination $e.id),
            (Join-Path $Destination (Split-Path $source -Leaf))
        )
        $copie = $null
        foreach ($cand in $candidats) {
            if (Test-Path -LiteralPath $cand) { $copie = $cand; break }
        }

        if (-not $copie) {
            $etatGlobal = 'manquant'
            $details += [ordered]@{
                chemin = $c; source = $source; etat = 'copie-absente'
                fichiersSource = $src.fichiers; fichiersCopie = 0
                octetsSource = $src.octets; octetsCopie = 0
            }
            continue
        }

        $dst = Measure-Contenu -Chemin $copie
        $ecart = 0.0
        if ($src.octets -gt 0) {
            $ecart = [math]::Abs($src.octets - $dst.octets) / [double]$src.octets * 100
        }
        $etat = 'ok'
        if ($dst.fichiers -lt $src.fichiers) { $etat = 'incomplet' }
        elseif ($ecart -gt $ToleranceParCent) { $etat = 'ecart-taille' }
        if ($etat -ne 'ok' -and $etatGlobal -ne 'manquant') { $etatGlobal = $etat }

        $details += [ordered]@{
            chemin = $c; source = $source; copie = $copie; etat = $etat
            fichiersSource = $src.fichiers; fichiersCopie = $dst.fichiers
            octetsSource = $src.octets; octetsCopie = $dst.octets
            ecartParCent = [math]::Round($ecart, 2)
        }
    }

    # Tout etait absent a la source : il n'y a rien a reprocher.
    $reels = @($details | Where-Object { $_.etat -ne 'source-absente' })
    if (-not @($reels).Count) { $etatGlobal = 'rien-a-sauvegarder' }

    switch ($etatGlobal) {
        'ok'                 { Write-Host " OK" -ForegroundColor Green }
        'rien-a-sauvegarder' { Write-Host " rien a sauvegarder" -ForegroundColor DarkGray }
        'manquant'           { Write-Host " COPIE ABSENTE" -ForegroundColor Red }
        'incomplet'          { Write-Host " INCOMPLET" -ForegroundColor Red }
        'ecart-taille'       { Write-Host " ecart de taille" -ForegroundColor Yellow }
        default              { Write-Host " $etatGlobal" -ForegroundColor Yellow }
    }
    foreach ($d in $details) {
        if ($d.etat -eq 'ok' -or $d.etat -eq 'source-absente') { continue }
        Write-Host "      $($d.chemin) : $($d.fichiersSource) fichier(s) / $(Format-Taille $d.octetsSource) a la source, $($d.fichiersCopie) / $(Format-Taille $d.octetsCopie) dans la copie" -ForegroundColor Yellow
    }

    $resultatsVerif += [ordered]@{
        id = $e.id; nom = $nom; etat = $etatGlobal; detail = ''; chemins = @($details)
    }
}

# ---------------------------------------------------------------- rapport

$ok       = @($resultatsVerif | Where-Object { $_.etat -eq 'ok' })
$problemes = @($resultatsVerif | Where-Object { $_.etat -in @('manquant', 'incomplet', 'ecart-taille') })
$nonVerif = @($resultatsVerif | Where-Object { $_.etat -eq 'non-verifiable' })

# Les elements verifies conformes peuvent etre coches sans y penser : on
# produit le meme format que le bouton Sauvegarder de la page.
$coches = @{}
$dates  = @{}
$maintenant = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
foreach ($r in $ok) { $coches[$r.id] = $true; $dates[$r.id] = $maintenant }

$rapport = [ordered]@{
    type    = 'sauvegardes-migration-pc'
    version = 3
    exported = $maintenant
    destination = $Destination
    resume  = [ordered]@{
        conformes = @($ok).Count; problemes = @($problemes).Count; nonVerifiables = @($nonVerif).Count
    }
    elements = @($resultatsVerif)
    # Relisible tel quel par le bouton Importer de la page.
    state   = [ordered]@{ checked = $coches; notes = @{}; dates = $dates; lic = @{}; env = @{} }
}

Set-Content -Path $Sortie -Value ($rapport | ConvertTo-Json -Depth 8) -Encoding UTF8
$chemin = (Resolve-Path $Sortie).Path

Write-Host ""
Write-Host "$(@($ok).Count) element(s) conforme(s), $(@($problemes).Count) a revoir, $(@($nonVerif).Count) non verifiable(s)." -ForegroundColor $(if (@($problemes).Count) { 'Yellow' } else { 'Green' })
if (@($problemes).Count) {
    Write-Host "A revoir :" -ForegroundColor Yellow
    foreach ($p in $problemes) { Write-Host "  - $($p.nom) ($($p.etat))" }
}
Write-Host "Rapport ecrit : $chemin"
Write-Host ""
Write-Host "Ce fichier est aussi une progression : l'importer dans index.html coche"
Write-Host "les elements verifies conformes."
Write-Host ""
