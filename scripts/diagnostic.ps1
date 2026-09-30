<#
.SYNOPSIS
    Ramasse ce qu'il faut savoir quand quelque chose s'est mal passe sur une
    vraie machine Windows.

.DESCRIPTION
    Ce programme n'a jamais tourne sur un Windows reel : tout est verifie par
    des tests sur donnees ecrites a la main, et par un job d'integration qui
    exerce le raisonnement, pas la machine. Le premier essai sur une vraie
    machine trouvera donc des choses, et ce script existe pour que cet
    aller-retour serve a quelque chose.

    Il ecrit un seul fichier, « diagnostic-migration-pc.txt », a cote de lui.

    CE QU'IL CONTIENT, ET CE QU'IL NE CONTIENT PAS. Le projet suit une regle
    constante : le nom dans l'inventaire, le secret ailleurs. Ce fichier-la va
    plus loin, parce qu'il est fait pour etre colle dans une conversation : il
    ne porte AUCUN nom de logiciel, aucun nom de machine, aucun numero de
    serie. Seulement des comptes, des versions, et les messages d'erreur que
    les detecteurs ont rendus.

    La sortie du scan est reprise telle quelle parce qu'elle est deja faite de
    comptes — « registre... 412 entrees », « Steam... non installe, ignore ».
    Un message d'erreur peut toutefois contenir un chemin de fichier : jetez-y
    un oeil avant de coller le fichier quelque part. C'est ecrit en tete du
    fichier produit, pour que personne ne l'apprenne apres coup.

.NOTES
    Windows. PowerShell 5.1 ou superieur.
    Rien n'est installe, rien n'est modifie : ce script lit et ecrit un fichier
    texte a cote de lui.

.EXAMPLE
    .\diagnostic.ps1
.EXAMPLE
    .\diagnostic.ps1 -Role cible
#>

[CmdletBinding()]
param(
    # Le cote a exercer. Le meme script de scan tourne des deux cotes, et un
    # defaut peut ne se voir que d'un seul.
    [ValidateSet('source', 'cible')]
    [string]$Role = 'source',
    # La langue de la sortie a examiner. Vide : celle de Windows, qui est
    # justement ce qu'on veut constater.
    [ValidateSet('fr', 'en')]
    [string]$Langue = ''
)

$ErrorActionPreference = 'Continue'   # un diagnostic ne s'arrete pas au premier ennui
Set-StrictMode -Version Latest

$Racine = $PSScriptRoot
if (-not $Racine) { $Racine = (Get-Location).Path }

$langueFichier = Join-Path $Racine 'lib-langue.ps1'
if (Test-Path -LiteralPath $langueFichier) {
    . $langueFichier
    Set-SortieUTF8
}

$sortie = Join-Path $Racine 'diagnostic-migration-pc.txt'
$lignes = New-Object System.Collections.ArrayList
function Noter($t) { [void]$lignes.Add([string]$t) }

Noter 'DIAGNOSTIC MIGRATION PC'
Noter ('Produit le ' + (Get-Date).ToString('yyyy-MM-dd HH:mm'))
Noter ''
Noter 'CE FICHIER NE PORTE AUCUN NOM DE LOGICIEL, DE MACHINE OU D''UTILISATEUR.'
Noter 'Seulement des comptes, des versions et des messages d''erreur. Un message'
Noter 'd''erreur peut contenir un chemin de fichier : parcourez-le avant de le'
Noter 'coller quelque part.'
Noter ''

# ── la machine, en gros traits ────────────────────────────────────────────
# Rien qui la designe : une version de Windows et une architecture ne
# distinguent pas une machine d'une autre.
Noter '--- l''environnement ---'
Noter ('PowerShell            : ' + $PSVersionTable.PSVersion + ' (' + $PSVersionTable.PSEdition + ')')
try {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    Noter ('Windows               : ' + $os.Caption + ' build ' + $os.BuildNumber)
} catch { Noter ('Windows               : indisponible (' + $_.Exception.Message + ')') }
$arch = $env:PROCESSOR_ARCHITECTURE
if (-not $arch) { $arch = '(non renseignee : ce n''est pas Windows)' }
Noter ('Architecture          : ' + $arch)

# CE QUI COMPTE VRAIMENT ICI. Deux defauts de cette serie venaient de la
# plateforme et non du code : la langue de l'interface, qui decide de celle des
# scripts, et l'encodage de la console, qui decide si les accents arrivent.
function NomCulture($c) {
    # La culture invariante rend un nom vide : hors de Windows on le dit, sinon
    # la ligne ressemble a une valeur perdue en route.
    if ($c.Name) { return $c.Name }
    return '(invariante : ce n''est pas Windows)'
}
Noter ('Langue de l''interface : ' + (NomCulture (Get-UICulture)))
Noter ('Format des nombres    : ' + (NomCulture (Get-Culture)))
if (Get-Command Get-LangueActive -ErrorAction SilentlyContinue) {
    Noter ('Langue retenue        : ' + (Set-Langue $Langue))
} else {
    Noter 'Langue retenue        : lib-langue.ps1 absent, non evaluable'
}
try {
    Noter ('Sortie console        : ' + [Console]::OutputEncoding.WebName +
        ' (page de code ' + [Console]::OutputEncoding.CodePage + ')')
} catch { Noter 'Sortie console        : non interrogeable' }
# La preuve par l'oeil : si cette ligne est abimee dans le fichier, l'encodage
# ne suit pas, et c'est la premiere chose a regarder.
# Si cette ligne est abimee dans le fichier, l'encodage ne suit pas, et c'est
# la premiere chose a regarder. Elle porte les accents que les scripts
# emploient reellement, et les guillemets francais du menu.
Noter 'Essai d''accents       : « été, où, ça, déjà,êtes, hôte » doit se lire sans charabia'
Noter ''

# ── les outils dont le scan depend ────────────────────────────────────────
Noter '--- les outils presents ---'
foreach ($outil in @('winget', 'pwsh', 'powershell')) {
    $c = Get-Command $outil -ErrorAction SilentlyContinue
    if ($c) {
        $v = ''
        if ($outil -eq 'winget') {
            try { $v = ' ' + ((& winget --version 2>$null) | Select-Object -First 1) } catch { }
        }
        Noter ($outil.PadRight(22) + ': present' + $v)
    } else {
        # Absent n'est pas en panne : la page le dit et le scan continue.
        Noter ($outil.PadRight(22) + ': absent (situation prevue, le scan continue)')
    }
}
Noter ''

# ── les fichiers du programme ─────────────────────────────────────────────
# Un fichier manquant explique la moitie des ennuis, et se voit d'un coup d'oeil.
Noter '--- les fichiers a cote ---'
foreach ($f in @('lib-langue.ps1', 'lib-detection.ps1', 'scan-pc.ps1',
                 'migration-pc.ps1', 'lanceur-actions.ps1', 'ecrire-resultat.ps1')) {
    $p = Join-Path $Racine $f
    Noter ($f.PadRight(22) + ': ' + $(if (Test-Path -LiteralPath $p) { 'present' } else { 'ABSENT' }))
}
$page = Join-Path $Racine '..\index.html'
Noter ('index.html            : ' + $(if (Test-Path -LiteralPath $page) { 'present' } else { 'ABSENT (la page ne se remplira pas seule)' }))
Noter ''

# ── le scan, dans un dossier a lui ────────────────────────────────────────
# Il ecrit des fichiers : on ne les seme pas a cote du programme, et on les
# efface apres. Seule sa sortie console est gardee, qui ne porte que des
# comptes.
Noter '--- ce que le scan ecrit a l''ecran ---'
Noter '(des comptes et des issues ; « absent, ignore » et « non installe, ignore »'
Noter ' sont des situations normales, pas des defauts)'
Noter ''
$scan = Join-Path $Racine 'scan-pc.ps1'
if (-not (Test-Path -LiteralPath $scan)) {
    Noter 'scan-pc.ps1 est absent : rien a exercer.'
} else {
    $bac = Join-Path ([System.IO.Path]::GetTempPath()) ('mpc-diag-' + [guid]::NewGuid().ToString('N'))
    [void](New-Item -ItemType Directory -Path $bac)
    try {
        $avant = Get-Location
        Set-Location $bac
        $debut = Get-Date
        $brut = & $scan -Role $Role -PasDOuverture -Langue $Langue 6>&1 2>&1 | Out-String
        $duree = [math]::Round(((Get-Date) - $debut).TotalSeconds, 1)
        Set-Location $avant
        $brutes = @($brut -split "`r?`n")
        for ($i = 0; $i -lt $brutes.Count; $i++) {
            $l = $brutes[$i]
            while ($l -match '\.\.\.\s*$' -and ($i + 1) -lt $brutes.Count) {
                $i++
                $l = $l + $brutes[$i]
            }
            Noter $l
        }
        Noter ''
        Noter ('Duree du scan         : ' + $duree + ' s')
        # La taille du fichier produit, pas son contenu : elle dit si le scan a
        # trouve quelque chose, sans rien reveler de ce qu'il a trouve.
        $produits = @(Get-ChildItem -LiteralPath $bac -Filter '*.json' -ErrorAction SilentlyContinue)
        Noter ('Fichiers produits     : ' + $produits.Count)
        foreach ($p in $produits) {
            Noter ('  ' + [math]::Round($p.Length / 1024, 1) + ' Ko (nom et contenu volontairement omis)')
        }
    } catch {
        Noter ('Le scan s''est arrete : ' + $_.Exception.Message)
        Noter ('  a ' + $_.InvocationInfo.PositionMessage)
    } finally {
        Set-Location $Racine
        Remove-Item -LiteralPath $bac -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$lignes -join "`r`n" | Set-Content -LiteralPath $sortie -Encoding UTF8
Write-Host ''
Write-Host ('Diagnostic ecrit : ' + $sortie) -ForegroundColor Green
Write-Host 'Ouvrez-le, parcourez-le, et collez-le dans la conversation.'
Write-Host 'Il ne porte aucun nom de logiciel ni de machine.'
