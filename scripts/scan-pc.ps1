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
    Write-ResultatPourSite -Donnees $inventaire -DossierScript $PSScriptRoot -NePasOuvrir:$PasDOuverture
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
    Write-Host "Etape suivante : ouvrir index.html, cliquer sur Importer, choisir ce fichier."
} else {
    Write-Host "Etape suivante : ouvrir index.html avec l'instantane de la source deja"
    Write-Host "importe, puis importer celui-ci. La page dira ce qui manque."
}
if (-not $ToutInclure) {
    Write-Host "Une entree manque ? Relancer avec -ToutInclure pour desactiver le filtrage."
}
Write-Host ""
