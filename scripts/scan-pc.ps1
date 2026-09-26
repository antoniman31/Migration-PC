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
# La console de Windows n'ecrit pas en UTF-8 par defaut : les accents de ce
# script y arriveraient en charabia. Les .bat font un « chcp 65001 », mais on
# peut aussi lancer ce fichier directement, et sous Windows PowerShell 5.1
# chcp ne suffit pas toujours. On le fixe ici, sans rien casser si l'hote
# refuse (redirection, console absente).
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch { }
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

# Une licence Windows OEM meurt avec la carte mere. Le savoir avant de
# commander la machine neuve coute une ligne de WMI ; l'apprendre apres coute
# le prix d'une licence.
$licences = Invoke-Detecteur -Nom 'licences' -Bloc { Read-Licences }

# Un logiciel payant se reinstalle comme les autres, puis refuse de demarrer.
# Certains rangent leur licence dans un fichier, en clair, a un endroit connu :
# on releve le chemin, jamais le contenu. L'inventaire voyage sur une cle USB.
$fichiersLicence = Invoke-Detecteur -Nom 'fichiers de licence' -Bloc { Read-FichiersLicence }

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

# Cinq familles que la checklist reclamait sans que rien n'aille les chercher.
# Les trois premieres se lisent sans droits particuliers ; BitLocker non, et il
# le dit au lieu de se taire.
$vpn = Invoke-Detecteur -Nom 'VPN' -Bloc { Read-Vpn -ClesInstallees @($resultats.Keys) }
$favoris = Invoke-Detecteur -Nom 'favoris' -Bloc { Read-Favoris }
$mail = Invoke-Detecteur -Nom 'archives mail' -Bloc { Read-ArchivesMail }
# Une machine virtuelle pese des dizaines de Go : c'est elle qui decide de la
# taille du disque a commander. La mesure est lente, d'ou le meme interrupteur
# que les gros dossiers.
$vm = @()
if (-not $SansGrosDossiers) {
    $vm = @(Invoke-Detecteur -Nom 'machines virtuelles' -Bloc { Read-MachinesVirtuelles })
}
$bitlocker = Invoke-Detecteur -Nom 'BitLocker' -Bloc { Read-Bitlocker }

# Des faits sur l'ancien PC plutot que des choses a copier : ils servent a
# commander la machine neuve et a la reconnaitre au SAV.
$machine = Invoke-Detecteur -Nom 'machine' -Bloc { Read-Machine }
$antivirus = Invoke-Detecteur -Nom 'antivirus' -Bloc { Read-Antivirus }
$pilotesTiers = Invoke-Detecteur -Nom 'pilotes tiers' -Bloc { Read-PilotesTiers }
$compte = Invoke-Detecteur -Nom 'compte Microsoft' -Bloc { Read-CompteMicrosoft }

# Ce qui se ressaisit plutot que de se copier : on releve les noms, jamais les
# secrets. Une cle Wi-Fi ou un mot de passe enregistre n'a rien a faire dans un
# inventaire qui voyage sur une cle USB.
$imprimantes = Invoke-Detecteur -Nom 'imprimantes' -Bloc { Read-Imprimantes }
$wifi = Invoke-Detecteur -Nom 'Wi-Fi' -Bloc { Read-Wifi }
$identifiants = Invoke-Detecteur -Nom 'identifiants' -Bloc { Read-Identifiants }
$polices = Invoke-Detecteur -Nom 'polices' -Bloc { Read-Polices }

# Des reglages qui ne se transportent pas, mais qu'on ne veut pas redecouvrir
# un par un le jour ou quelque chose ne marche plus comme avant.
$lecteurs = Invoke-Detecteur -Nom 'lecteurs reseau' -Bloc { Read-LecteursReseau }
$demarrage = Invoke-Detecteur -Nom 'demarrage' -Bloc { Read-Demarrage }
$taches = Invoke-Detecteur -Nom 'taches planifiees' -Bloc { Read-TachesPlanifiees }
$pareFeu = Invoke-Detecteur -Nom 'pare-feu' -Bloc { Read-PareFeu }
$associations = Invoke-Detecteur -Nom 'associations' -Bloc { Read-Associations }

$apps = $resultats.Values | Sort-Object { $_.nom }

$os = try { (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).Caption } catch { 'Windows' }

$inventaire = [ordered]@{
    type    = 'inventaire-migration-pc'
    version = 1
    genere  = (Get-Date).ToString('o')
    machine = (Merge-Machine -Base ([ordered]@{ os = $os; nom = $env:COMPUTERNAME }) -Ajouts $machine)
    apps    = @($apps)
    # Reprises telles quelles dans les champs prevus par la checklist.
    variables = $variables
    configs   = @($configs)
    # Ce que le scan a MESURE et propose d'emporter. Pas ce que la checklist
    # reclame par ailleurs : les chemins ecrits a la main n'ont pas de taille,
    # et pretendre le contraire donnerait un chiffre faux. Decouvrir la cle
    # pleine au milieu de la copie coute une soiree.
    # Les archives Outlook comptent, les caches .ost non : un .ost se
    # reconstruit tout seul a la premiere connexion, le faire tenir sur la cle
    # reviendrait a reserver huit gigaoctets pour rien. Les machines
    # virtuelles non plus : emporter 96 Go de VM est une decision, pas un
    # choix par defaut, et le chiffre annoncerait une cle qu'on n'a pas.
    aPrevoirMo = Get-TotalAPrevoirMo @($configs, $dossiers, $portables, $precieux,
        $fichiersLicence, (Select-AEmporter -Entrees $mail))
    materiel  = $materiel
    licences  = @($licences)
    fichiersLicence = @($fichiersLicence)
    vpn       = @($vpn)
    favoris   = @($favoris)
    mail      = @($mail)
    vm        = @($vm)
    bitlocker = @($bitlocker)
    antivirus = @($antivirus)
    pilotesTiers = @($pilotesTiers)
    compte    = $compte
    imprimantes = @($imprimantes)
    wifi      = @($wifi)
    identifiants = @($identifiants)
    polices   = @($polices)
    lecteurs  = @($lecteurs)
    demarrage = @($demarrage)
    taches    = @($taches)
    pareFeu   = @($pareFeu)
    associations = @($associations)
    outils    = @($outils)
    dossiers  = @($dossiers)
    precieux  = @($precieux)
    portables = @($portables)
}

$json = $inventaire | ConvertTo-Json -Depth 6
Write-TexteUtf8 -Chemin ([System.IO.Path]::GetFullPath($Sortie)) -Contenu $json

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
