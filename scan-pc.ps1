<#
.SYNOPSIS
    Inventorie les logiciels installes sur un PC Windows et produit un fichier JSON
    importable dans la checklist de migration (index.html).

.DESCRIPTION
    Le script interroge quatre sources et fusionne les resultats :
      - winget list        (identifiants d'installation officiels)
      - registre Uninstall (32 et 64 bits, machine et utilisateur)
      - applications du Microsoft Store (paquets APPX)
      - bibliotheques de jeux : Steam, Epic Games, GOG, Xbox
      - variables d'environnement personnalisees de l'utilisateur

    Aucune donnee ne quitte la machine : le script n'envoie rien sur le reseau,
    il ecrit uniquement un fichier JSON local que vous importez vous-meme.

.PARAMETER Sortie
    Chemin du fichier JSON produit. Par defaut inventaire-pc.json dans le dossier courant.

.PARAMETER SansStore
    Ignore les applications du Microsoft Store.

.PARAMETER SansJeux
    Ignore les bibliotheques de jeux : Steam, Epic Games, GOG et Xbox.

.PARAMETER SansVariables
    Ne releve pas les variables d'environnement personnalisees.

.PARAMETER SansOutils
    Ne releve pas les chaines d'outils : SDK Android, WSL, scoop, Chocolatey,
    paquets globaux npm et pip.

.PARAMETER SansGrosDossiers
    Ne cherche pas les gros dossiers du profil et des disques. C'est l'etape la
    plus longue du scan : elle lit des tailles, pas des fichiers, mais elle
    parcourt beaucoup.

.PARAMETER SeuilGo
    A partir de quelle taille un dossier est signale. 1 Go par defaut.

.PARAMETER ToutInclure
    Conserve aussi les entrees habituellement filtrees (redistribuables Visual C++,
    mises a jour, composants systeme). Produit une liste beaucoup plus longue.

.EXAMPLE
    .\scan-pc.ps1
    Scan standard, ecrit .\inventaire-pc.json

.EXAMPLE
    .\scan-pc.ps1 -Sortie D:\migration\inventaire.json -ToutInclure

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
    [string]$Sortie = "inventaire-pc.json",
    [switch]$SansStore,
    [switch]$SansJeux,
    [switch]$SansVariables,
    [switch]$SansConfigs,
    [switch]$SansOutils,
    [switch]$SansGrosDossiers,
    [double]$SeuilGo = 1,
    [switch]$ToutInclure
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
# ---------------------------------------------------------------- detection
# La detection est partagee avec verifier-pc.ps1 et verifier-sauvegardes.ps1 :
# elle vit dans lib-detection.ps1 pour n'exister qu'en un seul exemplaire.
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
$variables = if ($SansVariables) { [ordered]@{} } else {
    Invoke-Detecteur -Nom 'variables' -Bloc { Read-Variables }
}

# Les dossiers de configuration des logiciels qu'on vient de detecter :
# installer un logiciel prend une commande, retrouver ses reglages une soiree.
# Le materiel : Windows le connait, autant ne pas le faire saisir a la main.
$materiel = Invoke-Detecteur -Nom 'materiel' -Bloc { Read-Materiel }

# Une machine de developpement porte des chaines d'outils qu'aucun installateur
# n'enregistre : ni le registre, ni winget, ni le Store n'en savent rien. On ne
# les copie pas — elles pesent des dizaines de Go et se retelechargent — on
# emporte la liste et la commande qui remet chaque chose en place.
# Le projet ne detectait aucun fichier personnel : l'onglet « Donnees » est une
# liste ecrite a la main, et ce qui n'y figure pas n'est rappele par rien. Un
# logiciel oublie se reinstalle ; un dossier de photos oublie ne revient pas.
# On ne copie rien : on mesure, et la page dira ce qui est deja reclame.
$dossiers = @()
if (-not $SansGrosDossiers) {
    $dossiers = @(Invoke-Detecteur -Nom 'gros dossiers' -Bloc {
        Read-GrosDossiers -SeuilMo ([math]::Max(1, $SeuilGo * 1024))
    })
}

# Certains fichiers ne se recreent pas et ne vivent nulle part de previsible :
# un keystore de release Android perdu oblige a passer par la procedure de
# reinitialisation de cle de Google pour continuer a publier. Quelques
# kilo-octets, la ou son proprietaire l'a mis.
$precieux = @()
$portables = @()
if (-not $SansGrosDossiers) {
    $precieux = @(Invoke-Detecteur -Nom 'cles de signature' -Bloc { Read-FichiersPrecieux })
    # Un logiciel pose sans installateur n'a aucune entree de desinstallation,
    # aucun identifiant winget, rien dans le Store : aucune source ne le voit.
    # Ce releve est une liste de suspects a relire, pas un inventaire, et la
    # page le dit.
    $portables = @(Invoke-Detecteur -Nom 'logiciels portables' -Bloc { Read-Portables })
}

$outils = @()
if (-not $SansOutils) {
    $outils += @(Invoke-Detecteur -Nom 'SDK Android'      -Bloc { Read-SdkAndroid })
    $outils += @(Invoke-Detecteur -Nom 'WSL'              -Bloc { Read-Wsl })
    $outils += @(Invoke-Detecteur -Nom 'scoop/Chocolatey' -Bloc { Read-GestionnairesPaquets })
    $outils += @(Invoke-Detecteur -Nom 'npm/pip'          -Bloc { Read-OutilsLangages })
    $outils += @(Invoke-Detecteur -Nom 'extensions'       -Bloc { Read-Extensions })
}

$configs = if ($SansConfigs) { @() } else {
    @(Invoke-Detecteur -Nom 'configurations' -Bloc { Read-Configs -ClesInstallees @($resultats.Keys) })
}

$apps = $resultats.Values | Sort-Object { $_.nom }

$os = try { (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).Caption } catch { 'Windows' }

$inventaire = [ordered]@{
    type    = 'inventaire-migration-pc'
    version = 1
    genere  = (Get-Date).ToString('o')
    machine = [ordered]@{
        os  = $os
        nom = $env:COMPUTERNAME
    }
    apps    = @($apps)
    # Reprises telles quelles dans les champs prevus par la checklist.
    variables = $variables
    configs   = @($configs)
    # Ce que le scan a MESURE et propose d'emporter. Pas ce que la checklist
    # reclame par ailleurs : les chemins ecrits a la main n'ont pas de taille,
    # et pretendre le contraire donnerait un chiffre faux. Decouvrir la cle
    # pleine au milieu de la copie coute une soiree.
    aPrevoirMo = Get-TotalAPrevoirMo @($configs, $dossiers, $portables, $precieux)
    materiel  = $materiel
    outils    = @($outils)
    dossiers  = @($dossiers)
    precieux  = @($precieux)
    portables = @($portables)
}

$json = $inventaire | ConvertTo-Json -Depth 6
Set-Content -Path $Sortie -Value $json -Encoding UTF8

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
if (@($configs).Count) {
    $mo = Get-Somme $configs 'tailleMo'
    Write-Host "$(@($configs).Count) dossiers de configuration reperes$(if ($mo) { " ($([math]::Round($mo,0)) Mo)" })."
}
if ($inventaire.aPrevoirMo -gt 0) {
    $p = $inventaire.aPrevoirMo
    $lisible = if ($p -ge 1024) { "$([math]::Round($p / 1024, 1)) Go" } else { "$([math]::Round($p, 0)) Mo" }
    Write-Host ""
    Write-Host "A prevoir sur la cle : environ $lisible." -ForegroundColor Cyan
    Write-Host "  Ce que le scan a mesure. Ce que vous listez a la main s'ajoute."
}
if (@($portables).Count) {
    Write-Host "$(@($portables).Count) dossier(s) qui ressemblent a des logiciels portables."
    Write-Host "  A relire : rien ne permet de les distinguer a coup sur d un dossier avec un .exe."
}
if (@($precieux).Count) {
    Write-Host "$(@($precieux).Count) cle(s) de signature trouvee(s)." -ForegroundColor Yellow
    Write-Host "  Un keystore perdu ne se recree pas : il ouvre la porte a une procedure chez l editeur."
}
if (@($dossiers).Count) {
    $mo = Get-Somme $dossiers 'tailleMo'
    $poids = if ($mo -ge 1024) { "$([math]::Round($mo / 1024, 1)) Go" } else { "$([math]::Round($mo, 0)) Mo" }
    Write-Host "$(@($dossiers).Count) gros dossier(s) reperes$(if ($mo) { " ($poids au total)" })."
    Write-Host "  La page dira lesquels sont deja reclames par la checklist."
}
if (@($outils).Count) {
    $familles = @($outils | Group-Object -Property { $_.famille } | Sort-Object Name)
    Write-Host "$(@($outils).Count) outil(s) releve(s) : $(($familles | ForEach-Object { "$($_.Name) ($($_.Count))" }) -join ', ')."
    Write-Host "  Ils ne sont pas copies : la liste et leur commande d installation suffisent."
}
$nombreVariables = Get-Nombre $variables
if ($nombreVariables) {
    Write-Host ('{0} variable(s) d environnement relevee(s).' -f $nombreVariables)
}
Write-Host "Fichier ecrit : $chemin"
Write-Host ""
Write-Host "Etape suivante : ouvrir index.html, cliquer sur Importer, choisir ce fichier."
if (-not $ToutInclure) {
    Write-Host "Une entree manque ? Relancer avec -ToutInclure pour desactiver le filtrage."
}
Write-Host ""
