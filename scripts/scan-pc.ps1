<#
.SYNOPSIS
    Inventorie les logiciels installes sur un PC Windows et produit un fichier JSON
    importable dans la checklist de migration (index.html).

.DESCRIPTION
    Le script repond a deux questions, et a deux seulement :

      - quels logiciels sont installes ? (winget, registre Uninstall 32 et 64
        bits, Microsoft Store, et les bibliotheques Steam, Epic, GOG, Ubisoft,
        EA et Xbox)
      - quels pilotes sont en place, et lesquels manquent ?

    Le meme script tourne des deux cotes. Sur le PC source il fige l'etat a un
    instant donne ; sur le PC cible il constate ce qui est deja arrive, et
    releve en plus les peripheriques que Windows signale comme mal installes.
    La page compare les deux instantanes.

    Aucune donnee ne quitte la machine : le script n'envoie rien sur le reseau,
    il ecrit uniquement un fichier JSON local que vous importez vous-meme.

.PARAMETER Role
    'source' (defaut) pour le PC que vous quittez, 'cible' pour le PC neuf ou
    remis a zero. Sur la cible, le releve des pilotes manquants s'ajoute.

.PARAMETER Sortie
    Chemin du fichier JSON produit. Par defaut instantane-<role>-<date>.json
    dans le dossier courant, avec une copie nommee inventaire-pc.json.

.PARAMETER SansStore
    Ignore les applications du Microsoft Store.

.PARAMETER SansJeux
    Ignore les bibliotheques de jeux : Steam, Epic Games, GOG, Ubisoft, EA, Xbox.

.PARAMETER ToutInclure
    Conserve aussi les entrees habituellement filtrees (redistribuables Visual C++,
    mises a jour, composants systeme). Produit une liste beaucoup plus longue.

.EXAMPLE
    .\scan-pc.ps1
    Scan du PC source, ecrit .\instantane-source-<date>.json

.EXAMPLE
    .\scan-pc.ps1 -Role cible

.NOTES
    Windows uniquement. PowerShell 5.1 ou superieur.
    Si l'execution est bloquee :
        powershell -ExecutionPolicy Bypass -File .\scan-pc.ps1
    Les droits administrateur ne sont pas necessaires, mais sans eux certaines
    applications installees par d'autres comptes utilisateurs peuvent manquer.
#>

[CmdletBinding()]
param(
    [switch]$PasDOuverture,
    # Source ou cible. Le meme script tourne des deux cotes : d'un cote il
    # capture l'etat d'un PC, de l'autre il constate ce qui est deja arrive.
    # Deux instantanes de meme forme, que la page compare ensuite — plutot
    # qu'un second script qui redetecterait tout a sa facon.
    [ValidateSet('source', 'cible')]
    [string]$Role = 'source',
    # Vide : le nom est fabrique a partir du role et de la date. Un fichier
    # ecrase a chaque fois ne peut pas etre « l'etat d'un PC a un instant
    # donne », qui est pourtant tout l'objet de ce programme.
    [string]$Sortie = "",
    [switch]$SansStore,
    [switch]$SansJeux,
    [switch]$ToutInclure
)

# Le nom porte le role et le jour : on garde plusieurs instantanes sans qu'ils
# s'effacent, et on sait lequel on rejoue. Le raccourci « inventaire-pc.json »
# pointe toujours vers le dernier, pour que la page et les scripts n'aient
# rien a deviner.
if ([string]::IsNullOrWhiteSpace($Sortie)) {
    $Sortie = "instantane-$Role-" + (Get-Date).ToString('yyyy-MM-dd') + ".json"
}

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
# La console de Windows n'ecrit pas en UTF-8 par defaut : les accents de ce
# script y arriveraient en charabia. Les .bat font un « chcp 65001 », mais on
# peut aussi lancer ce fichier directement, et sous Windows PowerShell 5.1
# chcp ne suffit pas toujours. On le fixe ici, sans rien casser si l'hote
# refuse (redirection, console absente).
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch { }

# ---------------------------------------------------------------- detection
# La detection vit dans lib-detection.ps1 pour n'exister qu'en un seul
# exemplaire, quel que soit le cote sur lequel on tourne.
$lib = Join-Path $PSScriptRoot 'lib-detection.ps1'
if (-not (Test-Path $lib)) {
    Write-Error "lib-detection.ps1 est introuvable a cote de ce script. Copiez les deux fichiers ensemble."
    exit 1
}
. $lib

# Ecriture du resultat a cote de la page, et ouverture du navigateur.
$aide = Join-Path $PSScriptRoot 'ecrire-resultat.ps1'
if (Test-Path $aide) { . $aide }

# ---------------------------------------------------------------- execution

Write-Host ""
Write-Host "Inventaire des logiciels installes" -ForegroundColor Cyan
Write-Host "----------------------------------"

$null = Invoke-Detecteur -Nom 'Winget' -Bloc { Read-Winget }
$null = Invoke-Detecteur -Nom 'Registre' -Bloc { Read-Registre }
if (-not $SansStore) { $null = Invoke-Detecteur -Nom 'Store' -Bloc { Read-Store } }
if (-not $SansJeux) {
    $null = Invoke-Detecteur -Nom 'Steam' -Bloc { Read-Steam }
    $null = Invoke-Detecteur -Nom 'Epic' -Bloc { Read-Epic }
    $null = Invoke-Detecteur -Nom 'GOG' -Bloc { Read-GOG }
    $null = Invoke-Detecteur -Nom 'Ubisoft Connect' -Bloc { Read-Ubisoft }
    $null = Invoke-Detecteur -Nom 'EA App' -Bloc { Read-Ea }
    $null = Invoke-Detecteur -Nom 'Xbox' -Bloc { Read-Xbox }
}

# Le materiel : Windows le connait, autant ne pas le faire saisir a la main.
# Il sert ici a deux choses — savoir quels pilotes la cible devrait avoir, et
# reconnaitre la machine au SAV.
$materiel = Invoke-Detecteur -Nom 'materiel' -Bloc { Read-Materiel }

# Des faits sur la machine plutot que des choses a copier : marque, modele,
# numero de serie. C'est ce qui permet de fabriquer le lien vers la page de
# telechargement des pilotes du constructeur.
$machine = Invoke-Detecteur -Nom 'machine' -Bloc { Read-Machine }

# Les pilotes non-Microsoft deja en place. Sur la source, c'est la liste de ce
# qu'il faudra retrouver ; sur la cible, celle de ce qui est arrive.
$pilotesTiers = Invoke-Detecteur -Nom 'pilotes tiers' -Bloc { Read-PilotesTiers }

# Les peripheriques que Windows signale comme mal installes n'ont de sens que
# sur la machine d'arrivee : les relever sur le PC source ne dirait rien
# d'utile, on est en train de le quitter.
$pilotes = @()
if ($Role -eq 'cible') {
    $pilotes = @(Invoke-Detecteur -Nom 'pilotes manquants' -Bloc { Read-PilotesManquants })
}

$apps = $resultats.Values | Sort-Object { $_.nom }

$os = try { (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).Caption } catch { 'Windows' }

$inventaire = [ordered]@{
    type    = 'inventaire-migration-pc'
    version = 1
    # La page route le fichier sans rien demander : un instantane de cible ne
    # remplace pas la checklist, il sert a la comparer.
    role    = $Role
    genere  = (Get-Date).ToString('o')
    machine = (Merge-Machine -Base ([ordered]@{ os = $os; nom = $env:COMPUTERNAME }) -Ajouts $machine)
    apps    = @($apps)
    materiel = $materiel
    pilotesTiers = @($pilotesTiers)
    pilotes = @($pilotes)
}

$json = $inventaire | ConvertTo-Json -Depth 6
$cheminSortie = (Resolve-CheminSortie -Chemin $Sortie)
Write-TexteUtf8 -Chemin $cheminSortie -Contenu $json

# Le raccourci vers le dernier instantane. Une copie plutot qu'un lien : un
# lien symbolique demande des droits particuliers sous Windows, et se perd a
# la premiere copie sur une cle USB formatee en FAT32.
$raccourci = Join-Path (Split-Path $cheminSortie -Parent) 'inventaire-pc.json'
if ($raccourci -ne $cheminSortie) {
    try { Write-TexteUtf8 -Chemin $raccourci -Contenu $json }
    catch { Write-Host "  (raccourci inventaire-pc.json non ecrit : $_)" -ForegroundColor DarkGray }
}

# ------------------------------------------------- le relais par la cle USB
#
# La procedure tient en trois gestes : on scanne la source, on debranche la
# cle, on scanne la cible. Entre les deux il y a un changement de machine, donc
# un changement de navigateur : la memoire locale de la page, ou vit
# l'instantane de la source, ne traverse pas. Sur le PC neuf la page recevait
# donc un scan de cible et rien a quoi le comparer.
#
# Le relais, c'est la cle elle-meme. Le scan de la source depose une copie de
# son instantane a cote de index.html, sous un nom fixe ; celui de la cible la
# relit et la joint au resultat. Les deux voyagent alors ensemble, sans que
# personne ait un fichier a retrouver.
$dossierPage = if (Get-Command Get-DossierPage -ErrorAction SilentlyContinue) {
    Get-DossierPage -DossierScript $PSScriptRoot
} else { $null }
$relais = if ($dossierPage) { Join-Path $dossierPage 'instantane-source.json' } else { $null }

$instantaneSource = $null
if ($Role -eq 'source') {
    if ($relais) {
        try { Write-TexteUtf8 -Chemin $relais -Contenu $json }
        catch { Write-Host "  (copie pour la cle non ecrite : $_)" -ForegroundColor DarkGray }
    }
} elseif ($relais -and (Test-Path -LiteralPath $relais)) {
    # Un fichier illisible ou abime ne doit pas faire echouer le scan : la page
    # le dira, et l'instantane de la cible est deja ecrit.
    try {
        $instantaneSource = Get-Content -LiteralPath $relais -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-Host "  (instantane de la source illisible, ignore)" -ForegroundColor Yellow
    }
}

# ------------------------------------------- ce qui manque, pret a installer
#
# Calcule ici et non par la page, pour une raison prosaique : le fichier que la
# page produit part dans le dossier des telechargements du navigateur, et le
# lanceur n'a aucun moyen fiable de le retrouver. Le scan de la cible, lui, a
# les deux instantanes en main. On l'ecrit a cote de la page, ou le lanceur
# saura le lire.
#
# Ce fichier n'installe rien tout seul : c'est le lanceur qui propose de le
# jouer, apres avoir montre la liste et demande une confirmation.
$restant = $null
if ($Role -eq 'cible' -and $instantaneSource -and $dossierPage) {
    try {
        $manquantes = @(Get-AppsManquantes -Source $instantaneSource -Cible $inventaire)
        $restant = Join-Path $dossierPage 'winget-restant.json'
        if ($manquantes.Count) {
            Write-TexteUtf8 -Chemin $restant -Contenu ((Format-WingetImport -Manquantes $manquantes) | ConvertTo-Json -Depth 6)
        } else {
            # Rien a installer : le fichier d'un scan precedent mentirait.
            if (Test-Path -LiteralPath $restant) { Remove-Item -LiteralPath $restant -Force }
            $restant = $null
        }
    } catch {
        Write-Host "  (liste des manquants non ecrite : $_)" -ForegroundColor DarkGray
        $restant = $null
    }
}

# Sans ce fichier a cote, la page ne se remplit pas toute seule. C'est un
# confort, pas le resultat — le JSON est ecrit dans tous les cas — mais son
# absence se taisait, et on cherchait longtemps pourquoi la page restait vide.
if (-not (Get-Command Write-ResultatPourSite -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "ecrire-resultat.ps1 n'est pas a cote de ce script : la page ne se" -ForegroundColor Yellow
    Write-Host "remplira pas toute seule. Importez le fichier JSON a la main, ou" -ForegroundColor Yellow
    Write-Host "reprenez le dossier complet depuis le site." -ForegroundColor Yellow
}
if (Get-Command Write-ResultatPourSite -ErrorAction SilentlyContinue) {
    Write-ResultatPourSite -Donnees $inventaire -DossierScript $PSScriptRoot `
        -Source $instantaneSource -NePasOuvrir:$PasDOuverture
}

$avecWinget = @($apps | Where-Object { $_.winget }).Count
$totalGo = Get-Somme $apps 'tailleGo'
$chemin = (Resolve-Path $Sortie).Path

Write-Host ""
Write-Host "$(@($apps).Count) applications retenues, dont $avecWinget avec un identifiant winget." -ForegroundColor Green
if ($totalGo) {
    Write-Host "Taille connue : $([math]::Round($totalGo, 1)) Go — partielle, toutes les sources ne la donnent pas."
}
if (@($pilotesTiers).Count) {
    Write-Host "$(@($pilotesTiers).Count) pilote(s) non-Microsoft releve(s)."
}
if (@($pilotes).Count) {
    Write-Host "$(@($pilotes).Count) peripherique(s) sans pilote ou en erreur." -ForegroundColor Yellow
    Write-Host "  La page donne le lien du constructeur a partir du modele de la machine."
}
Write-Host "Fichier ecrit : $chemin"
Write-Host ""
if ($Role -eq 'source') {
    Write-Host "Etape suivante" -ForegroundColor Cyan
    Write-Host "  1. Debranchez cette cle USB."
    Write-Host "  2. Branchez-la sur le PC cible : le neuf, ou celui-ci une fois reinstalle."
    Write-Host "  3. Lancez « Migration PC.bat » et choisissez CIBLE."
    if (-not $relais) {
        Write-Host ""
        Write-Host "index.html n'est pas a cote des scripts : copiez le dossier entier sur la" -ForegroundColor Yellow
        Write-Host "cle, sinon le PC cible n'aura rien a comparer." -ForegroundColor Yellow
    }
} else {
    if ($instantaneSource) {
        Write-Host "La page s'ouvre sur ce qu'il reste a installer : les deux instantanes y sont."
        if ($restant) {
            Write-Host ""
            Write-Host "Etape suivante" -ForegroundColor Cyan
            Write-Host "  Relancez « Migration PC.bat » : il propose maintenant d'installer"
            Write-Host "  ce qui manque, apres vous avoir montre la liste."
        }
    } else {
        Write-Host "Aucun instantane du PC source sur cette cle : la page n'a rien a comparer." -ForegroundColor Yellow
        Write-Host "Scannez d'abord le PC source, ou importez son fichier a la main."
    }
}
if (-not $ToutInclure) {
    Write-Host "Une entree manque ? Relancer avec -ToutInclure pour desactiver le filtrage."
}
Write-Host ""
