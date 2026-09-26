<#
.SYNOPSIS
    Logique de detection partagee par les scripts du projet.

.DESCRIPTION
    Trois scripts interrogent les memes sources Windows : scan-pc.ps1 pour
    inventorier l'ancien PC, verifier-pc.ps1 pour constater ce qui est deja
    installe sur le nouveau, verifier-sauvegardes.ps1 pour les chemins.

    Ce fichier porte la detection une seule fois. Un defaut constate sur une
    machine se corrige ici et disparait des trois scripts, au lieu d'etre a
    reparer trois fois dans trois copies qui auront diverge.

    Il ne s'execute pas seul : les scripts l'importent par dot-sourcing.

.NOTES
    Windows uniquement. PowerShell 5.1 ou superieur.
    Les fonctions supposent que l'appelant a defini :
      $ToutInclure  (switch) desactive le filtrage des entrees sans interet
      $resultats    (hashtable) receptacle d'Add-App
#>

# Valeurs par defaut quand l'appelant ne les fournit pas : le fichier reste
# chargeable seul, par exemple depuis une suite de tests.
#
# Sous Set-StrictMode, LIRE une variable jamais definie est deja une erreur :
# la ligne censee fournir le defaut etait donc celle qui echouait. On teste
# l'existence sans lire la valeur.
if (-not (Get-Variable -Name 'ToutInclure' -Scope Script -ErrorAction SilentlyContinue)) {
    $script:ToutInclure = $false
}
if (-not (Get-Variable -Name 'resultats' -Scope Script -ErrorAction SilentlyContinue)) {
    $script:resultats = @{}
}

# ---------------------------------------------------------------- filtrage

# Entrees sans interet pour une reinstallation : composants embarques,
# redistribuables tires automatiquement par les applications, mises a jour.
$MotsExclus = @(
    'Microsoft Visual C++ 20', 'Redistributable', 'Update for', 'Security Update',
    'Hotfix', 'Language Pack', 'MSI Development', 'Windows SDK', 'Kit de developpement',
    'Definition Update', 'Service Pack', 'Driver Package', '.NET Framework',
    'Microsoft Edge Update', 'Google Update', 'Mise a jour'
)

# Ce qui vient AVEC Windows et se reinstalle tout seul. Un premier scan sur une
# vraie machine a rendu 271 entrees dont 52 de cette nature : extensions video
# du Store, moteurs d'execution, packs de langue, composants du systeme. Les
# lister n'aide personne — on ne les reinstalle pas, ils arrivent avec l'OS —
# et elles noient les logiciels qu'on veut vraiment retrouver.
#
# Les motifs sont volontairement precis. « Extension » tout court aurait
# emporte de vraies applications ; « Runtime » seul aurait emporte des moteurs
# de jeu qu'on veut garder.
$ComposantsWindows = @(
    # Moteurs d'execution et cadres applicatifs
    'WinAppRuntime', 'WindowsAppRuntime', 'VCLibs', 'UI.Xaml', 'Net Native',
    '.NET Core Runtime', '.NET Runtime', 'Desktop Runtime', 'ASP.NET Core',
    'Advertising SDK', 'Engagement Framework', 'D3DMappingLayers', 'GameInput',
    # Extensions media du Store
    'VideoExtension', 'ImageExtension', 'VideoExtensions', 'MediaExtensions',
    'Extension video', 'Extension d''image', 'Extensions video', 'Extensions de support web',
    'HEVCVideoExtension', 'AV1VideoExtension', 'VP9VideoExtension', 'WebpImageExtension',
    'HEIFImageExtension', 'RawImageExtension', 'MPEG2VideoExtension', 'AVCEncoderVideoExtension',
    # Langue, saisie, voix
    'LanguageExperiencePack', 'Experience locale', 'Ink.Handwriting', 'Windows.Speech',
    # Composants et services du systeme
    'SecHealthUI', 'StorePurchaseApp', 'WidgetsPlatformRuntime', 'Windows.CrossDevice',
    'Update Health Tools', 'GamingServices', 'Winget.Source', 'Winget.Fonts',
    'DesktopAppInstaller', 'OfficePushNotificationUtility', 'Office.ActionsServer',
    'PowerToys.SparseApp', 'ContextMenu', 'Hote de l', 'Experience du Microsoft Store',
    'Windows.Photos', 'WindowsStore', 'Microsoft Store',
    'compatibilite des applications', 'compatibilit', 'ApplicationCompatibility',
    'Local AI Manager', 'aimgr', 'Assistance au jeu', 'Edge.GameAssist',
    'Game Speech Window', 'XboxSpeechToText', 'MicrosoftFamily', 'Microsoft Family'
)

# Vrai si le nom designe un composant livre avec Windows.
function Test-ComposantWindows {
    param([string]$Nom)
    if ([string]::IsNullOrWhiteSpace($Nom)) { return $false }
    foreach ($m in $ComposantsWindows) {
        if ($Nom -like "*$m*") { return $true }
    }
    return $false
}

function Test-Exclu {
    param([string]$Nom)
    if ($ToutInclure) { return $false }
    if ([string]::IsNullOrWhiteSpace($Nom)) { return $true }
    foreach ($mot in $MotsExclus) {
        if ($Nom -like "*$mot*") { return $true }
    }
    if (Test-ComposantWindows -Nom $Nom) { return $true }
    return $false
}

# ---------------------------------------------------------------- couvertures
#
# Ce que le scanner sait reellement trouver, nomme une fois pour toutes.
#
# La checklist a ete ecrite a la main d'abord, comme une liste pour un humain ;
# le scanner est arrive apres et n'en couvre qu'une partie. Personne n'avait
# jamais compare les deux listes, et rien ne disait « cette ligne pretend etre
# verifiable, mais aucun detecteur ne la regarde ». C'est le meme sens manquant
# qui avait laisse ecrire-resultat.ps1 hors de la liste de telechargement.
#
# Chaque ligne de l'onglet « Donnees » du profil declare donc soit la
# couverture qui la remplit, soit qu'elle est manuelle. Un test refuse une
# couverture qui ne figure pas ici, et refuse une ligne qui ne declare rien.
$CouverturesScan = [ordered]@{
    apps       = 'Read-Registre, Read-Winget, Read-Store'
    jeux       = 'Read-Steam, Read-Epic, Read-GOG, Read-Xbox, Read-Ubisoft, Read-Ea'
    configs    = 'Read-Configs'
    variables  = 'Read-Variables'
    materiel   = 'Read-Materiel'
    licences   = 'Read-Licences'
    payants    = 'Get-LicenceAPrevoir, Read-FichiersLicence'
    vpn        = 'Read-Vpn'
    favoris    = 'Read-Favoris'
    vm         = 'Read-MachinesVirtuelles'
    mail       = 'Read-ArchivesMail'
    bitlocker  = 'Read-Bitlocker'
    machine    = 'Read-Machine'
    antivirus  = 'Read-Antivirus'
    pilotesTiers = 'Read-PilotesTiers'
    compte     = 'Read-CompteMicrosoft'
    imprimantes = 'Read-Imprimantes'
    wifi       = 'Read-Wifi'
    identifiants = 'Read-Identifiants'
    polices    = 'Read-Polices'
    lecteurs   = 'Read-LecteursReseau'
    demarrage  = 'Read-Demarrage'
    taches     = 'Read-TachesPlanifiees'
    pareFeu    = 'Read-PareFeu'
    associations = 'Read-Associations'
    controles  = 'Read-Controles'
    outils     = 'Read-SdkAndroid, Read-Wsl, Read-GestionnairesPaquets, Read-OutilsLangages'
    extensions = 'Read-Extensions'
    dossiers   = 'Read-GrosDossiers'
    precieux   = 'Read-FichiersPrecieux'
    portables  = 'Read-Portables'
    web        = 'Read-Registre (applications web du navigateur)'
}

# ---------------------------------------------------------------- categories

# Classement approximatif par mots-cles. Sert a pre-trier la checklist ;
# la categorie reste modifiable a la main dans le JSON produit.
$ReglesCategories = [ordered]@{
    dev          = @('Visual Studio', 'VS Code', 'Git', 'Python', 'Node', 'Java', 'JDK', 'Android Studio',
                     'IntelliJ', 'PyCharm', 'WebStorm', 'Docker', 'Unity', 'Godot', 'Unreal', 'Postman',
                     'PowerShell', 'Windows Terminal', 'Notepad++', 'Sublime', 'WinSCP', 'PuTTY', 'AutoHotkey')
    jeux         = @('Steam', 'Epic Games', 'GOG', 'Ubisoft', 'EA ', 'Battle.net', 'Riot', 'Minecraft',
                     'Xbox', 'Rockstar', 'Vortex', 'Wallpaper Engine', 'PlayStation')
    reseau       = @('VPN', 'qBittorrent', 'Transmission', 'NextDNS', 'Wireshark', 'FileZilla', 'Tailscale')
    securite     = @('Antivirus', 'Defender', 'Malwarebytes', 'Bitdefender', 'Kaspersky', 'KeePass',
                     'Bitwarden', '1Password', 'VeraCrypt')
    bureautique  = @('Office', 'Word', 'Excel', 'PowerPoint', 'Outlook', 'OneDrive', 'Chrome', 'Firefox',
                     'Edge', 'Opera', 'Brave', 'Acrobat', 'LibreOffice', 'Notion', 'Obsidian', 'Drive',
                     'Dropbox', 'Teams', 'Thunderbird')
    media        = @('VLC', 'Spotify', 'Deezer', 'iTunes', 'Audacity', 'OBS', 'Photoshop', 'Illustrator',
                     'GIMP', 'Krita', 'Blender', 'Premiere', 'DaVinci', 'Codec', 'Handbrake', 'foobar',
                     'Paint.NET', 'Inkscape', 'Plex')
    comms        = @('Discord', 'Slack', 'WhatsApp', 'Telegram', 'Signal', 'Zoom', 'Skype', 'Messenger')
    pilotes      = @('NVIDIA', 'AMD ', 'Radeon', 'Realtek', 'Intel', 'Logitech', 'Razer', 'SteelSeries',
                     'Corsair', 'iCUE', 'SignalRGB', 'Afterburner', 'Aura', 'Armoury', 'Elgato', 'Wacom')
    system       = @('7-Zip', 'WinRAR', 'CCleaner', 'HWiNFO', 'CrystalDisk', 'PowerToys', 'Rufus',
                     'Everything', 'TreeSize', 'WinDirStat', 'AIDA64', 'Revo', 'Ventoy', 'Windhawk')
}

function Get-Categorie {
    param([string]$Nom, [string]$Editeur)
    $cible = "$Nom $Editeur"
    foreach ($cat in $ReglesCategories.Keys) {
        foreach ($mot in $ReglesCategories[$cat]) {
            if ($cible -like "*$mot*") { return $cat }
        }
    }
    return 'system'
}

# Poids indicatifs : une suite lourde prend plus de temps qu'un petit utilitaire.
function Get-Duree {
    param([string]$Nom, [string]$Categorie)
    $lourds = @('Adobe', 'Visual Studio', 'Android Studio', 'Office', 'Unity', 'Unreal', 'Autodesk', 'MATLAB')
    foreach ($mot in $lourds) { if ($Nom -like "*$mot*") { return 30 } }
    switch ($Categorie) {
        'jeux'    { return 15 }
        'pilotes' { return 10 }
        default   { return 5 }
    }
}

function Get-Priorite {
    param([string]$Categorie)
    switch ($Categorie) {
        'pilotes'     { return 'high' }
        'securite'    { return 'high' }
        'bureautique' { return 'high' }
        'dev'         { return 'med' }
        'comms'       { return 'med' }
        'jeux'        { return 'ok' }
        default       { return 'med' }
    }
}

# Normalise un nom pour rapprocher deux entrees qui designent le meme logiciel.
function Get-Cle {
    param([string]$Nom)
    if ([string]::IsNullOrWhiteSpace($Nom)) { return '' }
    $n = $Nom.ToLowerInvariant()
    # Les mentions d'architecture et de langue varient d'une source a l'autre
    # pour un meme logiciel : « Mozilla Firefox (x64 fr) » et « Mozilla Firefox ».
    $n = $n -replace '\([^)]*\)', ''
    # Idem pour le numero de version, present dans le registre mais pas dans winget.
    # Effet de bord assume : deux versions majeures d'un meme logiciel (Python 3.12
    # et 3.13) fusionnent en une seule ligne de checklist.
    $n = $n -replace '\bversion\b|\bv?\d+(\.\d+)+\b', ''
    # Les numeros sans point echappaient a la ligne precedente : « Java 8 Update
    # 401 » et « Java 8 Update 411 » donnaient deux lignes pour un seul logiciel.
    $n = $n -replace '\b(update|build|release|rev|patch|sp)\s*\d+\b', ''
    # Tout ce qui suit un tiret isole est un suffixe de version ou d'edition
    # (« 7-Zip 23.01 - fr-FR ») ; le tiret colle a une lettre est garde, sinon
    # « 7-Zip » perdrait la moitie de son nom.
    $n = $n -replace '\s+-\s+.*$', ''
    # La ponctuation porte parfois le nom : « Notepad++ » et « Notepad » sont
    # deux logiciels. On la transcrit au lieu de l'effacer, sinon les deux
    # fusionnent et l'un des deux disparait de l'inventaire.
    $n = $n -replace '\+', 'p'
    $n = $n -replace '#', 'd'
    $n = $n -replace '[^a-z0-9]', ''
    return $n
}

# ---------------------------------------------------------------- collecte

$resultats = @{}   # cle normalisee -> objet application

function Add-App {
    param(
        [string]$Nom, [string]$Editeur, [string]$Version,
        [string]$Source, [string]$Winget,
        # Date d'installation, quand le registre la porte. Elle ne dit pas
        # depuis quand le logiciel n'a pas servi — Windows ne le sait pas —
        # mais « pose il y a quatre ans » suffit souvent a se souvenir
        # pourquoi, ou a constater qu'on ne s'en souvient plus.
        [string]$Installe = '',
        # Adresse officielle de l'editeur, quand le registre la porte.
        [string]$Lien = '',
        # Taille sur disque en Go, quand la source la connait. Sert a dimensionner
        # le disque du nouveau PC, pas a decider quoi reinstaller.
        $TailleGo = $null
    )
    if (Test-Exclu -Nom $Nom) { return }
    $cle = Get-Cle -Nom $Nom
    if ([string]::IsNullOrWhiteSpace($cle)) { return }

    if ($resultats.ContainsKey($cle)) {
        # Deja vu par une autre source : on complete les champs manquants.
        $exist = $resultats[$cle]
        if ([string]::IsNullOrWhiteSpace($exist.winget) -and $Winget) { $exist.winget = $Winget }
        if ([string]::IsNullOrWhiteSpace($exist.lien) -and $Lien) { $exist.lien = $Lien }
        if ([string]::IsNullOrWhiteSpace($exist.editeur) -and $Editeur) { $exist.editeur = $Editeur }
        if ([string]::IsNullOrWhiteSpace($exist.version) -and $Version) { $exist.version = $Version }
        if ($null -eq $exist.tailleGo -and $null -ne $TailleGo) { $exist.tailleGo = $TailleGo }
        if ([string]::IsNullOrWhiteSpace($exist.payant)) { $exist.payant = Get-LicenceAPrevoir -Nom $Nom -Editeur $Editeur }
        if ([string]::IsNullOrWhiteSpace($exist.installe) -and $Installe) { $exist.installe = $Installe }
        if ($exist.source -notlike "*$Source*") { $exist.source = "$($exist.source), $Source" }
        return
    }

    $cat = Get-Categorie -Nom $Nom -Editeur $Editeur
    $resultats[$cle] = [ordered]@{
        nom      = $Nom.Trim()
        editeur  = $Editeur
        version  = $Version
        source   = $Source
        winget   = $Winget
        lien     = $Lien
        cat      = $cat
        priorite = Get-Priorite -Categorie $cat
        duree    = Get-Duree -Nom $Nom -Categorie $cat
        tailleGo = $TailleGo
        # Vide quand on ne sait pas, ce qui est le cas le plus courant : la
        # liste est tenue a la main. Vide ne veut pas dire gratuit.
        payant   = Get-LicenceAPrevoir -Nom $Nom -Editeur $Editeur
        installe = $Installe
    }
}

# --- source 1 : winget -------------------------------------------------

# « winget list » melange deux choses qui n'ont rien a voir. Les paquets connus
# du catalogue portent un identifiant « Editeur.Produit » qui se reinstalle
# d'une commande. Les autres, ceux que winget a seulement apercus dans
# Ajout/Suppression de programmes, recoivent un identifiant fabrique sur place :
# « ARP\Machine\X64\{GUID} » ou « MSIX\... ». Celui-la ne s'installe pas, il ne
# sert qu'a la deduplication interne de winget.
#
# Notre ancien filtre rejetait bien ces identifiants — il exigeait un point et
# pas d'antislash — mais il ne le disait pas, et un relevé ou la moitie des
# lignes ressortait sans identifiant passait pour un bug de lecture de colonnes.
# Ce n'en etait pas forcement un : sur une machine ou peu de logiciels ont ete
# poses par winget, il est normal que presque aucun n'ait d'identifiant.
function Test-IdWingetInstallable {
    param([string]$Id)
    if ([string]::IsNullOrWhiteSpace($Id)) { return $false }
    $t = $Id.Trim()
    # Identifiants fabriques par winget pour ce qu'il n'a fait que decouvrir.
    if ($t -like 'ARP\*' -or $t -like 'MSIX\*' -or $t -like 'arp\*' -or $t -like 'msix\*') { return $false }
    if ($t.Contains('\')) { return $false }
    return ($t -match '^[A-Za-z0-9][A-Za-z0-9._-]*\.[A-Za-z0-9._-]+$')
}

# « winget export » ne sort que les paquets du catalogue, en JSON, sans colonne
# a largeur fixe ni accent a decaler. C'est la source d'identifiants la plus
# fiable dont on dispose, et le fichier se rejoue tel quel avec
# « winget import ». Il ne donne pas les noms d'affichage : c'est le registre
# qui les porte, et Merge-IdsWinget se charge du rapprochement.
function Read-ExportWinget {
    param([string]$Json)
    $ids = @()
    if ([string]::IsNullOrWhiteSpace($Json)) { return $ids }
    try { $d = $Json | ConvertFrom-Json } catch { return $ids }
    if (-not $d -or -not $d.PSObject.Properties['Sources']) { return $ids }
    foreach ($src in @($d.Sources)) {
        if (-not $src -or -not $src.PSObject.Properties['Packages']) { continue }
        foreach ($pkg in @($src.Packages)) {
            if (-not $pkg -or -not $pkg.PSObject.Properties['PackageIdentifier']) { continue }
            $id = [string]$pkg.PackageIdentifier
            if (-not (Test-IdWingetInstallable -Id $id)) { continue }
            $v = ''
            if ($pkg.PSObject.Properties['Version']) { $v = [string]$pkg.Version }
            $ids += [ordered]@{ id = $id.Trim(); version = $v }
        }
    }
    return $ids
}

# Un identifiant winget doit rejoindre la ligne d'inventaire du logiciel qu'il
# designe, pas en creer une deuxieme a cote. « Mozilla.Firefox » et la ligne du
# registre « Mozilla Firefox (x64 fr) » sont le meme logiciel.
#
# Deux rapprochements suffisent en pratique. Editeur et produit colles donnent
# « mozillafirefox », exactement ce que Get-Cle tire de « Mozilla Firefox ».
# Le produit seul donne « 7zip », ce que Get-Cle tire de « 7-Zip ». On essaie
# le plus specifique d'abord : le produit seul rapproche « Git.Git » de
# n'importe quel logiciel nomme « Git », le couple complet est plus sur.
function Get-ClesCandidatesWinget {
    param([string]$Id)
    $cles = @()
    if ([string]::IsNullOrWhiteSpace($Id)) { return $cles }
    $t = $Id.Trim()
    $i = $t.IndexOf('.')
    if ($i -le 0 -or $i -ge ($t.Length - 1)) { return @(Get-Cle -Nom $t) }
    $editeur = $t.Substring(0, $i)
    $produit = $t.Substring($i + 1)
    $cles += Get-Cle -Nom "$editeur $produit"
    $cles += Get-Cle -Nom $produit
    return @($cles | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
}

# Pose les identifiants de l'export sur les lignes deja connues, et cree une
# ligne pour ceux qui ne correspondent a rien : un paquet installe par winget
# mais absent du registre existe bel et bien, le perdre serait pire que
# l'afficher sous un nom approximatif.
function Merge-IdsWinget {
    param($Entrees)
    $poses = 0
    $crees = 0
    foreach ($e in @($Entrees)) {
        if (-not $e) { continue }
        $id = [string]$e.id
        if ([string]::IsNullOrWhiteSpace($id)) { continue }

        # Deja porte par une ligne : rien a faire.
        $deja = $false
        foreach ($v in $resultats.Values) { if ($v.winget -eq $id) { $deja = $true; break } }
        if ($deja) { continue }

        $trouve = $null
        foreach ($c in (Get-ClesCandidatesWinget -Id $id)) {
            if ($resultats.ContainsKey($c)) { $trouve = $resultats[$c]; break }
        }
        if ($trouve) {
            if ([string]::IsNullOrWhiteSpace($trouve.winget)) { $trouve.winget = $id; $poses++ }
            if ($trouve.source -notlike '*winget*') { $trouve.source = "$($trouve.source), winget" }
            continue
        }

        # Rien ne correspond : on fabrique un nom lisible a partir du produit.
        $i = $id.IndexOf('.')
        $nom = if ($i -gt 0 -and $i -lt ($id.Length - 1)) { $id.Substring($i + 1) } else { $id }
        Add-App -Nom $nom -Editeur $(if ($i -gt 0) { $id.Substring(0, $i) } else { '' }) `
                -Version ([string]$e.version) -Source 'winget' -Winget $id
        $crees++
    }
    return [ordered]@{ poses = $poses; crees = $crees }
}

function Read-Winget {
    Write-Host "  winget..." -NoNewline
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host " absent, ignore" -ForegroundColor Yellow
        return 0
    }
    $n = 0
    try {
        # --disable-interactivity coupe les indicateurs de progression. Sans
        # lui, winget ecrit des retours arriere (0x08) au milieu de sa sortie
        # et le decoupage en colonnes a largeur fixe part de travers.
        $lignes = & winget list --accept-source-agreements --disable-interactivity 2>$null | Out-String
        $lignes = $lignes -split "`r?`n"

        # La sortie est un tableau a colonnes fixes : on lit la ligne d'entete
        # pour connaitre la position des colonnes Id et Version.
        $entete = $lignes | Where-Object { $_ -match '^\s*(Name|Nom)\s+(Id|ID)\s+' } | Select-Object -First 1
        if (-not $entete) { Write-Host " sortie illisible, ignore" -ForegroundColor Yellow; return 0 }

        $posId  = $entete.IndexOf('Id')
        if ($posId -lt 0) { $posId = $entete.IndexOf('ID') }
        $posVer = [Math]::Max($entete.IndexOf('Version'), $entete.IndexOf('Versio'))
        if ($posId -lt 0 -or $posVer -le $posId) { Write-Host " colonnes illisibles, ignore" -ForegroundColor Yellow; return 0 }

        $debut = $false
        foreach ($l in $lignes) {
            if ($l -match '^-{5,}') { $debut = $true; continue }
            if (-not $debut) { continue }
            if ($l.Trim().Length -eq 0) { continue }
            # Restes d'indicateur de progression malgre --disable-interactivity.
            if ($l.Contains([char]8)) { continue }
            if ($l.Length -le $posId) { continue }

            $nom = $l.Substring(0, $posId).Trim()
            $reste = $l.Substring($posId)
            $decalageVer = $posVer - $posId
            if ($reste.Length -gt $decalageVer) {
                $id  = $reste.Substring(0, $decalageVer).Trim()
                $ver = $reste.Substring($decalageVer).Trim() -split '\s+' | Select-Object -First 1
            } else {
                $id  = $reste.Trim()
                $ver = ''
            }
            if ([string]::IsNullOrWhiteSpace($nom)) { continue }
            $idValide = Test-IdWingetInstallable -Id $id
            Add-App -Nom $nom -Editeur '' -Version $ver -Source 'winget' -Winget $(if ($idValide) { $id } else { '' })
            $n++
        }
    } catch {
        Write-Host " erreur ignoree : $($_.Exception.Message)" -ForegroundColor Yellow
        return $n
    }
    Write-Host " $n entrees"

    # Deuxieme passe, autoritaire : l'export ne contient que des identifiants
    # reellement reinstallables. Une panne ici ne doit pas perdre la premiere.
    try {
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("mpc-winget-" + [guid]::NewGuid().ToString('N') + ".json")
        & winget export --output $tmp --include-versions --accept-source-agreements --disable-interactivity 2>$null | Out-Null
        if (Test-Path -LiteralPath $tmp) {
            $json = Get-Content -LiteralPath $tmp -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            $entrees = @(Read-ExportWinget -Json $json)
            if ($entrees.Count) {
                $r = Merge-IdsWinget -Entrees $entrees
                Write-Host "  winget export... $($entrees.Count) identifiant(s), $($r.poses) pose(s), $($r.crees) ligne(s) ajoutee(s)"
            } else {
                Write-Host "  winget export... aucun paquet du catalogue" -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Host "  winget export... erreur ignoree : $($_.Exception.Message)" -ForegroundColor Yellow
    }
    return $n
}

# Le registre porte deja l'adresse officielle de l'editeur, dans URLInfoAbout
# et a defaut HelpLink. Personne ne la lisait, et la checklist proposait un
# lien de recherche Google la ou le disque connaissait le vrai site.
#
# On ne garde que http et https. Certains installateurs y mettent une adresse
# de desinstallation locale, un chemin de fichier ou une chaine vide entourees
# d'espaces : les afficher comme « site officiel » serait un mensonge.
function Get-LienEditeur {
    param($Entree)
    if (-not $Entree) { return '' }
    foreach ($champ in @('URLInfoAbout', 'HelpLink')) {
        $p = $Entree.PSObject.Properties[$champ]
        if (-not $p) { continue }
        $v = [string]$p.Value
        if ([string]::IsNullOrWhiteSpace($v)) { continue }
        $v = $v.Trim().Trim('"')
        if ($v -match '^https?://[^\s]+$') { return $v }
    }
    return ''
}

# --- source 2 : registre ------------------------------------------------
# InstallDate est ecrit « 20240317 » par la plupart des installateurs, et
# n'importe comment par les autres. On ne rend une date que si elle est
# plausible : une annee entre 1995 et l'annee prochaine, un mois et un jour
# qui existent.
function Format-DateInstallation {
    param([string]$Brut)
    if ([string]::IsNullOrWhiteSpace($Brut)) { return '' }
    $t = $Brut.Trim()
    if ($t -notmatch '^(\d{4})(\d{2})(\d{2})$') { return '' }
    $an = [int]$matches[1]; $mois = [int]$matches[2]; $jour = [int]$matches[3]
    if ($an -lt 1995 -or $an -gt ((Get-Date).Year + 1)) { return '' }
    if ($mois -lt 1 -or $mois -gt 12 -or $jour -lt 1 -or $jour -gt 31) { return '' }
    try { return (Get-Date -Year $an -Month $mois -Day $jour).ToString('yyyy-MM-dd') }
    catch { return '' }
}

function Read-Registre {
    Write-Host "  registre..." -NoNewline
    $chemins = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $n = 0
    foreach ($c in $chemins) {
        $entrees = Get-ItemProperty -Path $c -ErrorAction SilentlyContinue
        foreach ($e in $entrees) {
            $nom = $e.PSObject.Properties['DisplayName']
            if (-not $nom -or [string]::IsNullOrWhiteSpace($nom.Value)) { continue }
            # SystemComponent=1 : composant interne, jamais reinstalle a la main.
            $sc = $e.PSObject.Properties['SystemComponent']
            if ($sc -and $sc.Value -eq 1 -and -not $ToutInclure) { continue }
            $rel = $e.PSObject.Properties['ReleaseType']
            if ($rel -and $rel.Value -and -not $ToutInclure) { continue }

            $ed  = $e.PSObject.Properties['Publisher']
            $ver = $e.PSObject.Properties['DisplayVersion']
            # EstimatedSize est en kilo-octets, souvent absent ou fantaisiste :
            # on ne le reporte que s'il donne un resultat plausible.
            $taille = $null
            $es = $e.PSObject.Properties['EstimatedSize']
            if ($es -and $es.Value -is [int] -and $es.Value -gt 0) {
                $go = [math]::Round($es.Value / 1MB, 2)
                if ($go -gt 0) { $taille = $go }
            }
            $dateBrute = ''
            $di = $e.PSObject.Properties['InstallDate']
            if ($di -and $di.Value) { $dateBrute = [string]$di.Value }
            Add-App -Nom $nom.Value `
                    -Editeur $(if ($ed) { [string]$ed.Value } else { '' }) `
                    -Version $(if ($ver) { [string]$ver.Value } else { '' }) `
                    -Source 'registre' -Winget '' -TailleGo $taille `
                    -Installe (Format-DateInstallation -Brut $dateBrute) `
                    -Lien (Get-LienEditeur -Entree $e)
            $n++
        }
    }
    Write-Host " $n entrees"
    return $n
}

# Le Store rend l'editeur sous la forme d'un nom distingue de certificat :
# « CN=Microsoft Corporation, O=Microsoft Corporation, L=Redmond, S=Washington,
# C=US ». Recopie tel quel, ce pave partait dans l'inventaire puis s'affichait
# sous le nom du logiciel dans la checklist. Seul le CN interesse quelqu'un.
function Get-EditeurLisible {
    param([string]$Brut)
    if ([string]::IsNullOrWhiteSpace($Brut)) { return '' }
    if ($Brut -match '(?:^|,)\s*CN=([^,]+)') { return $matches[1].Trim(' "') }
    return $Brut.Trim()
}

# Un paquet du Store s'appelle « Editeur.NomDeLApp » : « Microsoft.Paint »,
# « A-Volute.Nahimic », et parfois avec un prefixe numerique attribue par le
# Store, « 5319275A.WhatsAppDesktop ». Seule la partie apres l'editeur est
# lisible par un humain.
#
# L'ancienne version remplacait « Microsoft » par « Microsoft » suivi d'une
# espace, et comme l'alternative sans point venait en premier, le point restait
# orphelin : 59 entrees d'un vrai scan s'appelaient « Microsoft .Paint ».
function Get-NomPaquetStore {
    param([string]$Nom)
    if ([string]::IsNullOrWhiteSpace($Nom)) { return '' }
    $n = $Nom.Trim()
    # On coupe au premier point : ce qui precede est l'editeur.
    $i = $n.IndexOf('.')
    if ($i -gt 0 -and $i -lt ($n.Length - 1)) { $n = $n.Substring($i + 1) }
    $n = $n.Trim()
    # Ce qui reste n'est parfois qu'un identifiant opaque — « 4297127D64EC6 ».
    # L'afficher n'apprend rien a personne.
    if ($n -match '^[0-9A-Fa-f]{8,}$') { return '' }
    return $n
}

# --- source 3 : Microsoft Store ----------------------------------------
function Read-Store {
    Write-Host "  Microsoft Store..." -NoNewline
    $n = 0
    try {
        $paquets = Get-AppxPackage -ErrorAction Stop |
            Where-Object { -not $_.IsFramework -and $_.SignatureKind -ne 'System' }
        foreach ($p in $paquets) {
            $lisible = Get-NomPaquetStore -Nom $p.Name
            if ([string]::IsNullOrWhiteSpace($lisible)) { continue }
            Add-App -Nom $lisible -Editeur (Get-EditeurLisible $p.Publisher) -Version $p.Version `
                    -Source 'Microsoft Store' -Winget ''
            $n++
        }
    } catch {
        Write-Host " indisponible, ignore" -ForegroundColor Yellow
        return 0
    }
    Write-Host " $n entrees"
    return $n
}

# --- source 4 : Steam ---------------------------------------------------
function Read-Steam {
    Write-Host "  Steam..." -NoNewline
    $racine = $null
    foreach ($k in @('HKCU:\SOFTWARE\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam')) {
        $v = Get-ItemProperty -Path $k -ErrorAction SilentlyContinue
        if ($v -and $v.PSObject.Properties['SteamPath']) { $racine = $v.SteamPath; break }
        if ($v -and $v.PSObject.Properties['InstallPath']) { $racine = $v.InstallPath; break }
    }
    if (-not $racine -or -not (Test-Path $racine)) {
        Write-Host " non installe, ignore" -ForegroundColor Yellow
        return 0
    }

    # Les jeux peuvent etre repartis sur plusieurs disques : libraryfolders.vdf les liste.
    $dossiers = @(Join-Path $racine 'steamapps')
    $vdf = Join-Path $racine 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
        foreach ($l in Get-Content $vdf -Encoding UTF8 -ErrorAction SilentlyContinue) {
            if ($l -match '"path"\s+"([^"]+)"') {
                $p = $matches[1] -replace '\\\\', '\'
                $sa = Join-Path $p 'steamapps'
                if ((Test-Path $sa) -and ($dossiers -notcontains $sa)) { $dossiers += $sa }
            }
        }
    }

    $n = 0
    foreach ($d in $dossiers) {
        Get-ChildItem -Path $d -Filter 'appmanifest_*.acf' -ErrorAction SilentlyContinue | ForEach-Object {
            $contenu = Get-Content $_.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            if ($contenu -match '"name"\s+"([^"]+)"') {
                $nomJeu = $matches[1]
                $taille = $null
                if ($contenu -match '"SizeOnDisk"\s+"(\d+)"') {
                    $taille = [math]::Round([double]$matches[1] / 1GB, 2)
                }
                Add-App -Nom $nomJeu -Editeur 'Steam' -Version '' -Source 'Steam' `
                        -Winget '' -TailleGo $taille
                $n++
            }
        }
    }
    Write-Host " $n jeux"
    return $n
}

# --- source 5 : Epic Games ---------------------------------------------
function Read-Epic {
    Write-Host "  Epic Games..." -NoNewline
    # Epic depose un manifeste JSON par jeu installe. Le dossier est fixe et
    # partage par toutes les installations, quel que soit le disque des jeux.
    $dossier = Join-CheminSur $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
    if (-not $dossier -or -not (Test-Path $dossier)) {
        Write-Host " non installe, ignore" -ForegroundColor Yellow
        return 0
    }
    $n = 0
    Get-ChildItem -Path $dossier -Filter '*.item' -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $m = Get-Content $_.FullName -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json
            $nom = $m.DisplayName
            if ([string]::IsNullOrWhiteSpace($nom)) { return }
            # Les greffons et redistribuables partagent le dossier avec les jeux.
            if ($m.PSObject.Properties['AppCategories'] -and
                $m.AppCategories -and ($m.AppCategories -notcontains 'games') -and -not $ToutInclure) { return }
            $taille = $null
            if ($m.PSObject.Properties['InstallSize'] -and $m.InstallSize) {
                $taille = [math]::Round($m.InstallSize / 1GB, 2)
            }
            Add-App -Nom $nom -Editeur 'Epic Games' -Version $m.AppVersionString `
                    -Source 'Epic Games' -Winget '' -TailleGo $taille
            $n++
        } catch { }
    }
    Write-Host " $n jeux"
    return $n
}

# --- source 6 : GOG Galaxy ---------------------------------------------
function Read-GOG {
    Write-Host "  GOG..." -NoNewline
    $n = 0
    foreach ($k in @('HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games\*', 'HKLM:\SOFTWARE\GOG.com\Games\*')) {
        Get-ItemProperty -Path $k -ErrorAction SilentlyContinue | ForEach-Object {
            $nom = $_.PSObject.Properties['gameName']
            if (-not $nom -or [string]::IsNullOrWhiteSpace($nom.Value)) { return }
            $ver = $_.PSObject.Properties['ver']
            Add-App -Nom $nom.Value -Editeur 'GOG' `
                    -Version $(if ($ver) { [string]$ver.Value } else { '' }) `
                    -Source 'GOG' -Winget ''
            $n++
        }
    }
    if ($n -eq 0) { Write-Host " non installe, ignore" -ForegroundColor Yellow; return 0 }
    Write-Host " $n jeux"
    return $n
}

# --- source 7 : Xbox / Game Pass ---------------------------------------
# Ce qui fait un jeu Xbox, et ce qui n'en fait pas un.
#
# « Tout paquet APPX hors de %ProgramFiles%\WindowsApps » etait trop large :
# Windows range ses propres composants dans C:\Windows\SystemApps, qui passait
# donc le filtre. L'inventaire se remplissait de SecHealthUI et de
# Win32WebViewHost, presentes comme des jeux Xbox.
#
# Deux conditions valent mieux qu'une negation : le paquet n'est ni un cadre ni
# un composant signe par le systeme, ET il est pose dans un magasin de jeux —
# « WindowsApps » sur un autre disque que celui de Windows, ou « XboxGames »,
# ou Microsoft range les installations recentes.
function Test-JeuXbox {
    param($Paquet)
    if ($null -eq $Paquet) { return $false }
    if ($Paquet.PSObject.Properties['IsFramework'] -and $Paquet.IsFramework) { return $false }
    if ($Paquet.PSObject.Properties['SignatureKind'] -and $Paquet.SignatureKind -eq 'System') { return $false }
    if (-not $Paquet.PSObject.Properties['InstallLocation']) { return $false }
    $ou = [string]$Paquet.InstallLocation
    if (-not $ou) { return $false }
    $systeme = "$env:ProgramFiles\WindowsApps"
    if ($systeme -and $ou -like "$systeme*") { return $false }
    return ($ou -like '*\WindowsApps\*' -or $ou -like '*\XboxGames\*')
}

function Read-Xbox {
    Write-Host "  Xbox / Game Pass..." -NoNewline
    # Les jeux Xbox sont des paquets APPX poses hors du dossier habituel :
    # c'est leur emplacement qui les distingue des applications du Store.
    $n = 0
    try {
        Get-AppxPackage -ErrorAction Stop |
            Where-Object { Test-JeuXbox -Paquet $_ } |
            ForEach-Object {
                $nom = $_.Name -replace '^[A-Za-z0-9]+\.', ''
                Add-App -Nom $nom -Editeur 'Xbox' -Version $_.Version -Source 'Xbox' -Winget ''
                $n++
            }
    } catch {
        Write-Host " indisponible, ignore" -ForegroundColor Yellow
        return 0
    }
    if ($n -eq 0) { Write-Host " aucun jeu, ignore" -ForegroundColor Yellow; return 0 }
    Write-Host " $n jeux"
    return $n
}

# --- variables d'environnement -----------------------------------------
# Les variables personnalisees ne se retrouvent pas apres une reinstallation :
# la checklist a des champs pour les noter, autant les remplir directement.
# Seules celles de l'utilisateur sont lues : celles du systeme sont recreees
# par Windows et par les installateurs.
function Read-Variables {
    Write-Host "  variables d'environnement..." -NoNewline
    $vars = [ordered]@{}
    $standard = @('PATH','TEMP','TMP','OS','COMSPEC','PATHEXT','PROCESSOR_ARCHITECTURE',
                  'PROCESSOR_IDENTIFIER','PROCESSOR_LEVEL','PROCESSOR_REVISION',
                  'NUMBER_OF_PROCESSORS','WINDIR','SYSTEMROOT','SYSTEMDRIVE',
                  'USERPROFILE','USERNAME','USERDOMAIN','HOMEDRIVE','HOMEPATH',
                  'APPDATA','LOCALAPPDATA','PROGRAMDATA','PUBLIC','ALLUSERSPROFILE',
                  'PROGRAMFILES','PROGRAMFILES(X86)','PROGRAMW6432','COMMONPROGRAMFILES',
                  'COMMONPROGRAMFILES(X86)','COMMONPROGRAMW6432','PSMODULEPATH',
                  'LOGONSERVER','USERDOMAIN_ROAMINGPROFILE','SESSIONNAME','DRIVERDATA',
                  'ONEDRIVE','ONEDRIVECONSUMER','ONEDRIVECOMMERCIAL')
    try {
        $utilisateur = [Environment]::GetEnvironmentVariables('User')
        foreach ($cle in $utilisateur.Keys) {
            if ($standard -contains $cle.ToString().ToUpperInvariant()) { continue }
            $vars[[string]$cle] = [string]$utilisateur[$cle]
        }
        # Le PATH utilisateur n'existe que si on y a ajoute quelque chose.
        $pathUtil = [Environment]::GetEnvironmentVariable('PATH', 'User')
        if ($pathUtil) { $vars['PATH (utilisateur)'] = $pathUtil }
    } catch {
        Write-Host " illisibles, ignore" -ForegroundColor Yellow
        return [ordered]@{}
    }
    Write-Host " $(Get-Nombre $vars) relevee(s)"
    return $vars
}

# --- source 8 : Ubisoft Connect ----------------------------------------
#
# Ubisoft tient ses installations dans HKLM\SOFTWARE\Ubisoft\Launcher\Installs :
# une sous-cle par jeu, portant le dossier d'installation mais pas le nom. Le
# nom se deduit donc du dossier — c'est ce que font les autres outils qui lisent
# cette cle, faute de mieux.
function Format-JeuxUbisoft {
    param($Entrees)
    $out = @()
    foreach ($e in @($Entrees)) {
        if ($null -eq $e) { continue }
        $dossier = ''
        if ($e -is [System.Collections.IDictionary]) {
            if ($e.Contains('dossier')) { $dossier = [string]$e['dossier'] }
        } elseif ($e.PSObject.Properties['dossier']) { $dossier = [string]$e.dossier }
        if ([string]::IsNullOrWhiteSpace($dossier)) { continue }
        $nom = Split-Path $dossier.TrimEnd('\', '/') -Leaf
        if ([string]::IsNullOrWhiteSpace($nom)) { continue }
        $out += [ordered]@{ nom = $nom; dossier = $dossier }
    }
    return $out
}

function Read-Ubisoft {
    Write-Host "  Ubisoft Connect..." -NoNewline
    $entrees = @()
    foreach ($k in @('HKLM:\SOFTWARE\WOW6432Node\Ubisoft\Launcher\Installs\*',
                     'HKLM:\SOFTWARE\Ubisoft\Launcher\Installs\*')) {
        foreach ($e in @(Get-ItemProperty -Path $k -ErrorAction SilentlyContinue)) {
            if (-not $e.PSObject.Properties['InstallDir']) { continue }
            $entrees += [ordered]@{ dossier = [string]$e.InstallDir }
        }
    }
    $jeux = @(Format-JeuxUbisoft -Entrees $entrees)
    if (-not $jeux.Count) { Write-Host " non installe, ignore" -ForegroundColor Yellow; return 0 }
    $n = 0
    foreach ($j in $jeux) {
        Add-App -Nom $j.nom -Editeur 'Ubisoft' -Version '' -Source 'Ubisoft Connect' -Winget ''
        $n++
    }
    Write-Host " $n jeux"
    return $n
}

# --- source 9 : EA App / Origin ----------------------------------------
#
# L'EA App ne tient pas de registre de ses jeux : chacun depose un
# « __Installer\installerdata.xml » dans son propre dossier. La presence de ce
# fichier distingue un jeu d'un dossier quelconque pose au meme endroit.
function Format-JeuxEa {
    param([string[]]$Racines)
    $out = @()
    foreach ($r in @($Racines)) {
        if ([string]::IsNullOrWhiteSpace($r)) { continue }
        if (-not (Test-Path -LiteralPath $r)) { continue }
        foreach ($d in @(Get-ChildItem -LiteralPath $r -Directory -Force -ErrorAction SilentlyContinue)) {
            $marqueur = Join-Path $d.FullName '__Installer\installerdata.xml'
            if (-not (Test-Path -LiteralPath $marqueur)) { continue }
            $out += [ordered]@{ nom = $d.Name; dossier = $d.FullName }
        }
    }
    return $out
}

function Get-RacinesEa {
    $r = @()
    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        foreach ($nom in @('EA Games', 'Origin Games')) {
            $c = Join-CheminSur $base $nom
            if ($c) { $r += $c }
        }
    }
    return $r
}

function Read-Ea {
    Write-Host "  EA App..." -NoNewline
    $jeux = @(Format-JeuxEa -Racines (Get-RacinesEa))
    if (-not $jeux.Count) { Write-Host " non installe, ignore" -ForegroundColor Yellow; return 0 }
    $n = 0
    foreach ($j in $jeux) {
        Add-App -Nom $j.nom -Editeur 'Electronic Arts' -Version '' -Source 'EA App' -Winget ''
        $n++
    }
    Write-Host " $n jeux"
    return $n
}

# ---------------------------------------------------------------- extensions
#
# La checklist conseillait « la synchronisation des paramètres restaure
# extensions et reglages » : un conseil, pas un releve. Reinstaller trente
# extensions a la main est exactement la soiree que ce projet evite.
#
# On ne copie pas les extensions : on les nomme, avec de quoi les remettre.

# VS Code pose un dossier par extension, nomme « editeur.nom-version ».
# Pas besoin de lancer `code` : le nom du dossier dit tout.
function Format-ExtensionsVsCode {
    param([string]$Racine)
    $out = @()
    if ([string]::IsNullOrWhiteSpace($Racine) -or -not (Test-Path -LiteralPath $Racine)) { return $out }
    foreach ($d in @(Get-ChildItem -LiteralPath $Racine -Directory -Force -ErrorAction SilentlyContinue)) {
        $n = $d.Name
        # La version est en fin de nom, precedee d'un tiret. Ce qui reste est
        # l'identifiant que `code --install-extension` reprend tel quel.
        $id = $n
        $version = ''
        if ($n -match '^(.+)-(\d+\.\d+[\.\d]*)$') { $id = $matches[1]; $version = $matches[2] }
        if ($id -notmatch '^[^.]+\.[^.]+') { continue }
        $out += New-Outil -Famille 'Extensions VS Code' -Id $id -Version $version `
            -Commande "code --install-extension $id"
    }
    return $out
}

# Les navigateurs Chromium posent un dossier par extension, nomme de son
# identifiant, avec un sous-dossier par version contenant le manifeste. Le nom
# lisible y est souvent une reference de traduction (« __MSG_appName__ ») :
# quand c'est le cas, on garde l'identifiant plutot que d'afficher un jeton.
function Format-ExtensionsChromium {
    param([string]$Racine, [string]$Navigateur = 'Chrome')
    $out = @()
    if ([string]::IsNullOrWhiteSpace($Racine) -or -not (Test-Path -LiteralPath $Racine)) { return $out }
    foreach ($d in @(Get-ChildItem -LiteralPath $Racine -Directory -Force -ErrorAction SilentlyContinue)) {
        $id = $d.Name
        # Un identifiant d'extension Chromium fait 32 lettres a..p.
        if ($id -notmatch '^[a-p]{32}$') { continue }
        $nom = ''
        $version = ''
        $derniere = @(Get-ChildItem -LiteralPath $d.FullName -Directory -Force -ErrorAction SilentlyContinue |
                      Sort-Object Name) | Select-Object -Last 1
        if ($derniere) {
            $version = $derniere.Name
            $manifeste = Join-Path $derniere.FullName 'manifest.json'
            if (Test-Path -LiteralPath $manifeste) {
                try {
                    $m = Get-Content -LiteralPath $manifeste -Raw -Encoding UTF8 | ConvertFrom-Json
                    if ($m -and $m.PSObject.Properties['name']) {
                        $brut = [string]$m.name
                        if ($brut -and $brut -notlike '__MSG_*') { $nom = $brut }
                    }
                } catch { }
            }
        }
        $out += New-Outil -Famille "Extensions $Navigateur" -Id $id `
            -Nom $(if ($nom) { $nom } else { $id }) -Version $version `
            -Commande "https://chromewebstore.google.com/detail/$id"
    }
    return $out
}

# Firefox tient un extensions.json par profil : les noms y sont deja lisibles.
function Format-ExtensionsFirefox {
    param([string]$Json)
    $out = @()
    if ([string]::IsNullOrWhiteSpace($Json)) { return $out }
    try { $d = $Json | ConvertFrom-Json } catch { return $out }
    if (-not $d -or -not $d.PSObject.Properties['addons']) { return $out }
    foreach ($a in @($d.addons)) {
        if ($null -eq $a) { continue }
        # Les greffons livres avec Firefox ne se reinstallent pas.
        if ($a.PSObject.Properties['location'] -and $a.location -ne 'app-profile') { continue }
        $id = ''
        if ($a.PSObject.Properties['id']) { $id = [string]$a.id }
        if ([string]::IsNullOrWhiteSpace($id)) { continue }
        $nom = $id
        if ($a.PSObject.Properties['defaultLocale'] -and $a.defaultLocale -and
            $a.defaultLocale.PSObject.Properties['name'] -and $a.defaultLocale.name) {
            $nom = [string]$a.defaultLocale.name
        }
        $version = ''
        if ($a.PSObject.Properties['version']) { $version = [string]$a.version }
        $out += New-Outil -Famille 'Extensions Firefox' -Id $id -Nom $nom -Version $version `
            -Commande "https://addons.mozilla.org/firefox/search/?q=$([uri]::EscapeDataString($nom))"
    }
    return $out
}

function Read-Extensions {
    Write-Host "  extensions..." -NoNewline
    $out = @()
    $vsc = Join-CheminSur $env:USERPROFILE '.vscode\extensions'
    $out += @(Format-ExtensionsVsCode -Racine $vsc)

    $chromiums = @(
        @{ nom = 'Chrome'; chemin = 'Google\Chrome\User Data\Default\Extensions' }
        @{ nom = 'Edge';   chemin = 'Microsoft\Edge\User Data\Default\Extensions' }
        @{ nom = 'Brave';  chemin = 'BraveSoftware\Brave-Browser\User Data\Default\Extensions' }
    )
    foreach ($c in $chromiums) {
        $r = Join-CheminSur $env:LOCALAPPDATA $c.chemin
        $out += @(Format-ExtensionsChromium -Racine $r -Navigateur $c.nom)
    }

    $profils = Join-CheminSur $env:APPDATA 'Mozilla\Firefox\Profiles'
    if ($profils -and (Test-Path -LiteralPath $profils)) {
        foreach ($p in @(Get-ChildItem -LiteralPath $profils -Directory -Force -ErrorAction SilentlyContinue)) {
            $f = Join-Path $p.FullName 'extensions.json'
            if (-not (Test-Path -LiteralPath $f)) { continue }
            try { $out += @(Format-ExtensionsFirefox -Json (Get-Content -LiteralPath $f -Raw -Encoding UTF8)) } catch { }
        }
    }
    if (-not $out.Count) { Write-Host " aucune, ignore" -ForegroundColor Yellow; return @() }
    Write-Host " $($out.Count) extension(s)"
    return $out
}

# ---------------------------------------------------------------- gros dossiers
#
# Le projet ne detectait aucun fichier personnel : l'onglet « Donnees » est une
# liste de chemins ecrite a la main, qu'on coche en confiance. Si un dossier n'y
# figure pas, rien ne le rappelle. Un logiciel oublie se reinstalle ; un dossier
# de photos oublie ne revient pas.
#
# On ne copie rien et on ne devine rien : on mesure, on signale ce qui pese, et
# la page dit ce qui est deja reclame par la checklist. Elle seule connait la
# liste ; le script, lui, connait le disque.

# Ce que Windows gere lui-meme : le signaler n'apprendrait rien et noierait le
# reste.
$script:DossiersSysteme = @(
    'Windows', 'Program Files', 'Program Files (x86)', 'ProgramData', 'PerfLogs',
    '$Recycle.Bin', 'System Volume Information', 'Recovery', '$WinREAgent',
    'Config.Msi', 'MSOCache', 'Intel', 'AMD', 'NVIDIA', 'hiberfil.sys',
    'AppData', 'Application Data', 'Local Settings', 'Cookies', 'NetHood',
    'PrintHood', 'Recent', 'SendTo', 'Templates', 'Voisinage d''impression',
    'Voisinage reseau', 'Menu Demarrer', 'Mes documents'
)

function Test-DossierSysteme {
    param([string]$Nom)
    if ([string]::IsNullOrWhiteSpace($Nom)) { return $true }
    foreach ($s in $script:DossiersSysteme) {
        if ($Nom -eq $s) { return $true }
    }
    return $false
}

# La taille d'un dossier, avec un budget de temps. Un disque de plusieurs
# teraoctets ne se parcourt pas en entier pendant qu'on attend devant l'ecran :
# mieux vaut une mesure partielle annoncee comme telle qu'un script qui semble
# fige. Les points de jonction ne sont pas suivis : ils bouclent.
function Measure-DossierBudget {
    param([string]$Chemin, [System.Diagnostics.Stopwatch]$Chrono, [double]$BudgetSecondes = 60)
    $octets = [int64]0
    $complet = $true
    try {
        foreach ($f in (Get-ChildItem -LiteralPath $Chemin -Recurse -File -Force -ErrorAction SilentlyContinue)) {
            if ($f.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
            $octets += $f.Length
            if ($Chrono -and $Chrono.Elapsed.TotalSeconds -gt $BudgetSecondes) { $complet = $false; break }
        }
    } catch { $complet = $false }
    return [ordered]@{ octets = $octets; complet = $complet }
}

# Les dossiers directement sous une racine, mesures un par un. On ne descend
# pas plus bas : « D:\Projets » se signale mieux que ses quarante sous-dossiers.
function Measure-DossiersEnfants {
    param(
        [string]$Racine,
        [double]$SeuilMo = 1024,
        [double]$BudgetSecondes = 60,
        [string]$Modele = ''
    )
    $out = @()
    if ([string]::IsNullOrWhiteSpace($Racine) -or -not (Test-Path -LiteralPath $Racine)) { return $out }
    $chrono = [System.Diagnostics.Stopwatch]::StartNew()
    $enfants = @(Get-ChildItem -LiteralPath $Racine -Directory -Force -ErrorAction SilentlyContinue)
    foreach ($d in $enfants) {
        if (Test-DossierSysteme -Nom $d.Name) { continue }
        if ($d.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
        $m = Measure-DossierBudget -Chemin $d.FullName -Chrono $chrono -BudgetSecondes $BudgetSecondes
        $mo = [math]::Round($m.octets / 1MB, 1)
        if ($mo -lt $SeuilMo) { continue }
        $out += [ordered]@{
            nom      = $d.Name
            chemin   = $d.FullName
            # Variabilise quand la racine l'est : un dossier du profil se
            # retrouvera sous un autre nom d'utilisateur, un dossier de disque
            # non.
            modele   = if ($Modele) { (($Modele.TrimEnd('\', '/')) + '\' + $d.Name) } else { '' }
            tailleMo = $mo
            complet  = $m.complet
        }
        if ($chrono.Elapsed.TotalSeconds -gt $BudgetSecondes) { break }
    }
    return $out
}

function Get-RacinesAExplorer {
    $racines = @()
    if ($env:USERPROFILE -and (Test-Path -LiteralPath $env:USERPROFILE)) {
        $racines += [ordered]@{ chemin = $env:USERPROFILE; modele = '%USERPROFILE%' }
    }
    # Les disques fixes seulement : une cle USB ou un disque reseau branche au
    # moment du scan ne decrit pas la machine.
    try {
        foreach ($d in (Get-CimInstance Win32_LogicalDisk -Filter 'DriveType = 3' -ErrorAction Stop)) {
            $r = ($d.DeviceID + '\')
            if ($env:SystemDrive -and $r -like ($env:SystemDrive + '*')) { continue }
            if (Test-Path -LiteralPath $r) { $racines += [ordered]@{ chemin = $r; modele = '' } }
        }
    } catch { }
    return $racines
}

function Read-GrosDossiers {
    param([double]$SeuilMo = 1024, [double]$BudgetSecondes = 120)
    Write-Host "  gros dossiers..." -NoNewline
    $out = @()
    $racines = @(Get-RacinesAExplorer)
    if (-not $racines.Count) { Write-Host " aucune racine, ignore" -ForegroundColor Yellow; return @() }
    $part = if ($racines.Count) { $BudgetSecondes / $racines.Count } else { $BudgetSecondes }
    foreach ($r in $racines) {
        $out += @(Measure-DossiersEnfants -Racine $r.chemin -SeuilMo $SeuilMo `
                    -BudgetSecondes $part -Modele $r.modele)
    }
    $partiels = @($out | Where-Object { -not $_.complet }).Count
    Write-Host " $($out.Count) au-dessus du seuil$(if ($partiels) { ", $partiels mesure(s) partiellement" })"
    return $out
}

# ---------------------------------------------------------------- fichiers rares
#
# Certains fichiers ne se recreent pas et ne vivent nulle part de previsible.
# Un keystore de release Android en est le cas type : perdu, il faut passer par
# la procedure de reinitialisation de cle de Google pour continuer a publier.
# Il pese quelques kilo-octets et se trouve la ou son proprietaire l'a mis,
# souvent dans un dossier de projet. On ne peut pas deviner ou ; on peut
# chercher, et le signaler.
#
# On ne copie rien : on nomme, et la checklist s'occupe du reste.

$script:ExtensionsPrecieuses = @('.jks', '.keystore', '.pfx', '.p12')

# Ce qui produit du bruit : des keystores de test, des certificats
# d'echafaudage, des copies de cache. Les signaler noierait le vrai.
$script:DossiersBruyants = @(
    'node_modules', '.gradle', '.m2', 'caches', 'AppData', 'Windows',
    'Program Files', 'Program Files (x86)', 'ProgramData', '$Recycle.Bin',
    '.git', 'build', 'vendor', 'Packages', 'AndroidStudio', 'Sdk', 'venv',
    '.venv', 'site-packages', 'target', 'dist', 'obj'
)

function Test-DossierBruyant {
    param([string]$Chemin)
    if ([string]::IsNullOrWhiteSpace($Chemin)) { return $false }
    $bouts = ($Chemin -replace '/', '\') -split '\\'
    foreach ($b in $bouts) {
        foreach ($n in $script:DossiersBruyants) {
            if ($b -eq $n) { return $true }
        }
    }
    return $false
}

function Find-FichiersPrecieux {
    param([string]$Racine, [double]$BudgetSecondes = 30, [string]$Modele = '')
    $out = @()
    if ([string]::IsNullOrWhiteSpace($Racine) -or -not (Test-Path -LiteralPath $Racine)) { return $out }
    $chrono = [System.Diagnostics.Stopwatch]::StartNew()
    $base = (Get-Item -LiteralPath $Racine -Force -ErrorAction SilentlyContinue)
    if (-not $base) { return $out }
    $prefixe = $base.FullName.TrimEnd('\', '/')
    # Pas de -Include : combine a -LiteralPath, Windows PowerShell 5.1 l'ignore
    # purement et simplement et rend TOUS les fichiers. Sur une vraie machine,
    # la recherche de cles aurait donc rapporte le disque entier. PowerShell 7
    # le respecte, ce qui rendait le defaut invisible ici — c'est le job Windows
    # qui l'a trouve, a son premier passage utile.
    foreach ($f in (Get-ChildItem -LiteralPath $Racine -Recurse -File -Force -ErrorAction SilentlyContinue)) {
        if ($chrono.Elapsed.TotalSeconds -gt $BudgetSecondes) { break }
        if ($script:ExtensionsPrecieuses -notcontains $f.Extension.ToLowerInvariant()) { continue }
        $dossier = Split-Path $f.FullName -Parent
        if (Test-DossierBruyant -Chemin $dossier.Substring([math]::Min($prefixe.Length, $dossier.Length))) { continue }
        # Le modele decrit un chemin Windows : on ne laisse pas se melanger les
        # deux separateurs, sinon il ne se relit nulle part.
        $rel = ($f.FullName.Substring($prefixe.Length) -replace '/', '\').TrimStart('\')
        $out += [ordered]@{
            nom      = $f.Name
            chemin   = $f.FullName
            modele   = if ($Modele) { ($Modele.TrimEnd('\', '/') + '\' + $rel) } else { '' }
            tailleKo = [math]::Round($f.Length / 1KB, 1)
        }
    }
    return $out
}

function Read-FichiersPrecieux {
    param([double]$BudgetSecondes = 60)
    Write-Host "  clés de signature..." -NoNewline
    $racines = @(Get-RacinesAExplorer)
    if (-not $racines.Count) { Write-Host " aucune racine, ignore" -ForegroundColor Yellow; return @() }
    $part = $BudgetSecondes / $racines.Count
    $out = @()
    foreach ($r in $racines) {
        $out += @(Find-FichiersPrecieux -Racine $r.chemin -BudgetSecondes $part -Modele $r.modele)
    }
    if (-not $out.Count) { Write-Host " aucune trouvée" -ForegroundColor Yellow; return @() }
    Write-Host " $($out.Count) fichier(s)"
    return $out
}

# ---------------------------------------------------------------- portable
#
# Un logiciel pose sans installateur — un .exe dezippe dans un dossier — n'a
# aucune entree de desinstallation, aucun identifiant winget, rien dans le
# Store. Aucune des sources du scan ne le voit. Il part donc avec le disque,
# et il ne revient pas.
#
# Ce qui suit n'est PAS un inventaire, et ne pretend pas l'etre : c'est une
# liste de suspects a relire. On ne sait pas distinguer a coup sur un logiciel
# portable d'un dossier qui contient un .exe. On limite donc le bruit autant
# que possible, et on annonce ce que c'est.

# Ce qui accompagne un logiciel sans etre le logiciel.
$script:ExesIgnorables = @(
    'setup', 'install', 'installer', 'uninstall', 'uninst', 'unins000',
    'update', 'updater', 'crashpad_handler', 'crashreporter', 'vcredist',
    'helper', 'elevate', 'launcher-installer', 'repair', 'maintenanceservice',
    'dotnetfx', 'wixstub', 'notification_helper', 'squirrel'
)

function Test-ExeIgnorable {
    param([string]$Nom)
    if ([string]::IsNullOrWhiteSpace($Nom)) { return $true }
    $base = [System.IO.Path]::GetFileNameWithoutExtension($Nom).ToLowerInvariant()
    foreach ($i in $script:ExesIgnorables) {
        if ($base -eq $i) { return $true }
        if ($base -like "$i*") { return $true }
    }
    return $false
}

# Les dossiers ou chercher n'ont rien a voir avec ceux ou chercher des cles :
# ici on evite en plus tout ce qui appartient a un logiciel deja installe.
$script:DossiersNonPortables = @(
    'Windows', 'Program Files', 'Program Files (x86)', 'ProgramData', 'AppData',
    '$Recycle.Bin', 'System Volume Information', 'Recovery', 'PerfLogs',
    'node_modules', '.git', '.gradle', '.m2', 'caches', 'cache', 'venv', '.venv',
    'site-packages', 'build', 'dist', 'obj', 'target', 'vendor', 'Sdk',
    'steamapps', 'WindowsApps', 'XboxGames', 'EA Games', 'Origin Games',
    'Temp', 'tmp', '.vscode', '.android', 'OneDriveTemp'
)

function Test-DossierNonPortable {
    param([string]$Chemin)
    if ([string]::IsNullOrWhiteSpace($Chemin)) { return $false }
    foreach ($b in (($Chemin -replace '/', '\') -split '\\')) {
        foreach ($n in $script:DossiersNonPortables) {
            if ($b -eq $n) { return $true }
        }
    }
    return $false
}

# Un dossier ressemble a un logiciel portable quand il contient peu
# d'executables et qu'aucun n'est un installateur. Beaucoup d'executables au
# meme endroit, c'est une collection ou un dossier systeme, pas une
# application : on ne le propose pas.
function Format-Portables {
    param(
        [string]$Racine,
        [int]$Profondeur = 3,
        [int]$MaxExes = 4,
        [string[]]$ClesInstallees = @(),
        [string]$Modele = '',
        [double]$BudgetSecondes = 30
    )
    $out = @()
    if ([string]::IsNullOrWhiteSpace($Racine) -or -not (Test-Path -LiteralPath $Racine)) { return $out }
    $chrono = [System.Diagnostics.Stopwatch]::StartNew()
    $base = (Get-Item -LiteralPath $Racine -Force -ErrorAction SilentlyContinue)
    if (-not $base) { return $out }
    $prefixe = $base.FullName.TrimEnd('\', '/')

    $aVoir = New-Object System.Collections.Queue
    $aVoir.Enqueue(@{ chemin = $prefixe; niveau = 0 })
    while ($aVoir.Count -gt 0) {
        if ($chrono.Elapsed.TotalSeconds -gt $BudgetSecondes) { break }
        $courant = $aVoir.Dequeue()
        $enfants = @(Get-ChildItem -LiteralPath $courant.chemin -Directory -Force -ErrorAction SilentlyContinue)
        foreach ($d in $enfants) {
            if (Test-DossierNonPortable -Chemin $d.Name) { continue }
            if ($d.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
            if ($courant.niveau + 1 -lt $Profondeur) {
                $aVoir.Enqueue(@{ chemin = $d.FullName; niveau = $courant.niveau + 1 })
            }
            $exes = @(Get-ChildItem -LiteralPath $d.FullName -File -Force -ErrorAction SilentlyContinue |
                      Where-Object { $_.Extension -eq '.exe' })
            if (-not $exes.Count) { continue }
            $utiles = @($exes | Where-Object { -not (Test-ExeIgnorable -Nom $_.Name) })
            if (-not $utiles.Count) { continue }
            if ($utiles.Count -gt $MaxExes) { continue }
            # Deja installe par ailleurs : le registre l'a vu, inutile de le
            # proposer une seconde fois sous un autre nom.
            $cle = Get-Cle -Nom $d.Name
            if ($cle -and ($ClesInstallees -contains $cle)) { continue }
            $rel = ($d.FullName.Substring($prefixe.Length) -replace '/', '\').TrimStart('\')
            $out += [ordered]@{
                nom    = $d.Name
                chemin = $d.FullName
                modele = if ($Modele) { ($Modele.TrimEnd('\', '/') + '\' + $rel) } else { '' }
                exes   = @($utiles | ForEach-Object { $_.Name })
                # Mesure pour que le total a prevoir ne mente pas par omission :
                # un dossier propose a la copie sans sa taille fausse le compte.
                tailleMo = Get-TailleDossier -Chemin $d.FullName
            }
        }
    }
    return $out
}

function Read-Portables {
    param([double]$BudgetSecondes = 60)
    Write-Host "  logiciels portables..." -NoNewline
    $racines = @(Get-RacinesAExplorer)
    if (-not $racines.Count) { Write-Host " aucune racine, ignore" -ForegroundColor Yellow; return @() }
    $cles = @($resultats.Keys)
    $part = $BudgetSecondes / $racines.Count
    $out = @()
    foreach ($r in $racines) {
        $out += @(Format-Portables -Racine $r.chemin -ClesInstallees $cles `
                    -Modele $r.modele -BudgetSecondes $part)
    }
    if (-not $out.Count) { Write-Host " aucun repere" -ForegroundColor Yellow; return @() }
    Write-Host " $($out.Count) a relire"
    return $out
}

# ---------------------------------------------------------------- outils
#
# Une machine de developpement porte des choses qu'aucun installateur
# n'enregistre : le SDK Android, les distributions WSL, les paquets de scoop et
# de Chocolatey, les outils globaux de npm, pip ou cargo. Rien de tout cela
# n'apparait dans le registre, ni dans winget, ni dans le Store. Le scan les
# ignorait donc entierement.
#
# On ne les copie pas : ils pesent des dizaines de Go et se retelechargent.
# Ce qu'on emporte, c'est la LISTE — et pour chacun la commande qui le remet en
# place. C'est exactement ce qu'on fait deja pour les logiciels avec winget.
#
# La lecture et la mise en forme sont separees : trouver un SDK sur la machine
# ne se teste que sur Windows, mettre en forme ce qu'on y a lu se teste partout.

function New-Outil {
    param([string]$Famille, [string]$Id, [string]$Nom, [string]$Version, [string]$Commande)
    return [ordered]@{
        famille  = $Famille
        id       = $Id
        nom      = if ($Nom) { $Nom } else { $Id }
        version  = $Version
        commande = $Commande
    }
}

# Le SDK Android se lit dans son arborescence, sans lancer sdkmanager : c'est
# plus rapide, cela ne demande pas de Java, et les identifiants obtenus sont
# exactement ceux que sdkmanager reprend pour reinstaller.
function Format-PaquetsSdk {
    param([string]$Racine)
    $out = @()
    if ([string]::IsNullOrWhiteSpace($Racine) -or -not (Test-Path -LiteralPath $Racine)) { return $out }
    # Chaque famille se lit pareil : un dossier, un sous-dossier par version,
    # et un identifiant « famille;version » que sdkmanager comprend.
    $familles = @(
        @{ dossier = 'platforms';    prefixe = 'platforms' }
        @{ dossier = 'build-tools';  prefixe = 'build-tools' }
        @{ dossier = 'ndk';          prefixe = 'ndk' }
        @{ dossier = 'cmake';        prefixe = 'cmake' }
        @{ dossier = 'system-images'; prefixe = 'system-images'; profond = $true }
    )
    foreach ($f in $familles) {
        $d = Join-Path $Racine $f.dossier
        if (-not (Test-Path -LiteralPath $d)) { continue }
        if ($f.Contains('profond') -and $f.profond) {
            # system-images;android-34;google_apis;x86_64 : trois niveaux.
            foreach ($a in @(Get-ChildItem -LiteralPath $d -Directory -ErrorAction SilentlyContinue)) {
                foreach ($b in @(Get-ChildItem -LiteralPath $a.FullName -Directory -ErrorAction SilentlyContinue)) {
                    foreach ($c in @(Get-ChildItem -LiteralPath $b.FullName -Directory -ErrorAction SilentlyContinue)) {
                        $id = "$($f.prefixe);$($a.Name);$($b.Name);$($c.Name)"
                        $out += New-Outil -Famille 'SDK Android' -Id $id -Commande "sdkmanager `"$id`""
                    }
                }
            }
            continue
        }
        foreach ($v in @(Get-ChildItem -LiteralPath $d -Directory -ErrorAction SilentlyContinue)) {
            $id = "$($f.prefixe);$($v.Name)"
            $out += New-Outil -Famille 'SDK Android' -Id $id -Commande "sdkmanager `"$id`""
        }
    }
    # Les outils sans version : un dossier, pas de sous-dossier par version.
    foreach ($seul in @('platform-tools', 'emulator', 'tools')) {
        if (Test-Path -LiteralPath (Join-Path $Racine $seul)) {
            $out += New-Outil -Famille 'SDK Android' -Id $seul -Commande "sdkmanager `"$seul`""
        }
    }
    return $out
}

function Get-RacineSdkAndroid {
    # L'ordre suit celui d'Android Studio : la variable d'abord, puis
    # l'emplacement par defaut.
    foreach ($v in @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT)) {
        if ($v -and (Test-Path -LiteralPath $v)) { return $v }
    }
    $defaut = Join-CheminSur $env:LOCALAPPDATA 'Android\Sdk'
    if ($defaut -and (Test-Path -LiteralPath $defaut)) { return $defaut }
    return $null
}

function Read-SdkAndroid {
    Write-Host "  SDK Android..." -NoNewline
    $racine = Get-RacineSdkAndroid
    if (-not $racine) { Write-Host " absent, ignore" -ForegroundColor Yellow; return @() }
    $p = @(Format-PaquetsSdk -Racine $racine)
    Write-Host " $($p.Count) paquet(s)"
    return $p
}

# wsl.exe ecrit en UTF-16 : lu naivement, chaque nom arrive espace de caracteres
# nuls. Le piege est connu et coute une heure a qui l'ignore.
function Format-DistributionsWsl {
    param([string[]]$Lignes)
    $out = @()
    foreach ($l in @($Lignes)) {
        if ($null -eq $l) { continue }
        $n = ($l -replace "`0", '').Trim()
        if (-not $n) { continue }
        # L'en-tete de `wsl --list` n'est pas une distribution.
        if ($n -match '^(Windows Subsystem|Sous-syst|NAME\s|NOM\s)') { continue }
        $defaut = $false
        if ($n -match '^\*\s*') { $defaut = $true; $n = $n -replace '^\*\s*', '' }
        # `--list --verbose` ajoute l'etat et la version : on ne garde que le nom.
        $n = ($n -split '\s{2,}')[0].Trim()
        if (-not $n) { continue }
        if ($n -match '\(' ) { continue }
        $out += New-Outil -Famille 'WSL' -Id $n `
            -Nom $(if ($defaut) { "$n (par defaut)" } else { $n }) `
            -Commande "wsl --install -d $n"
    }
    return $out
}

function Read-Wsl {
    Write-Host "  distributions WSL..." -NoNewline
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        Write-Host " absent, ignore" -ForegroundColor Yellow; return @()
    }
    try {
        $avant = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.Encoding]::Unicode
        try { $brut = @(& wsl.exe --list --quiet 2>$null) }
        finally { [Console]::OutputEncoding = $avant }
    } catch {
        Write-Host " illisible, ignore" -ForegroundColor Yellow; return @()
    }
    $d = @(Format-DistributionsWsl -Lignes $brut)
    Write-Host " $($d.Count) distribution(s)"
    return $d
}

# scoop et Chocolatey installent des logiciels qui n'apparaissent ni dans le
# registre ni dans winget : un dossier par paquet, c'est tout.
function Format-PaquetsDossier {
    param([string]$Racine, [string]$Famille, [string]$Modele)
    $out = @()
    if ([string]::IsNullOrWhiteSpace($Racine) -or -not (Test-Path -LiteralPath $Racine)) { return $out }
    foreach ($d in @(Get-ChildItem -LiteralPath $Racine -Directory -ErrorAction SilentlyContinue)) {
        if ($d.Name -eq 'scoop') { continue }   # scoop se gere lui-meme
        $out += New-Outil -Famille $Famille -Id $d.Name -Commande ($Modele -f $d.Name)
    }
    return $out
}

function Read-GestionnairesPaquets {
    Write-Host "  scoop et Chocolatey..." -NoNewline
    $out = @()
    $scoop = Join-CheminSur $env:USERPROFILE 'scoop\apps'
    $out += @(Format-PaquetsDossier -Racine $scoop -Famille 'scoop' -Modele 'scoop install {0}')
    $choco = Join-CheminSur $env:ProgramData 'chocolatey\lib'
    $out += @(Format-PaquetsDossier -Racine $choco -Famille 'Chocolatey' -Modele 'choco install {0}')
    if (-not $out.Count) { Write-Host " absents, ignore" -ForegroundColor Yellow; return @() }
    Write-Host " $($out.Count) paquet(s)"
    return $out
}

# npm ls -g --json rend un objet dependencies : un nom, une version.
function Format-PaquetsNpm {
    param([string]$Json)
    $out = @()
    if ([string]::IsNullOrWhiteSpace($Json)) { return $out }
    try { $d = $Json | ConvertFrom-Json } catch { return $out }
    if (-not $d -or -not $d.PSObject.Properties['dependencies']) { return $out }
    # npm et corepack sont livres avec Node : les reinstaller n'a pas de sens,
    # et les voir dans la liste ferait douter du reste.
    $livresAvecNode = @('npm', 'corepack')
    foreach ($p in @($d.dependencies.PSObject.Properties)) {
        if ($livresAvecNode -contains $p.Name) { continue }
        $v = ''
        if ($p.Value -and $p.Value.PSObject.Properties['version']) { $v = [string]$p.Value.version }
        $out += New-Outil -Famille 'npm (global)' -Id $p.Name -Version $v `
            -Commande "npm install -g $($p.Name)"
    }
    return $out
}

# pip list --format=freeze : « nom==version », une ligne par paquet.
function Format-PaquetsPip {
    param([string[]]$Lignes)
    $out = @()
    foreach ($l in @($Lignes)) {
        if ([string]::IsNullOrWhiteSpace($l)) { continue }
        $t = $l.Trim()
        if ($t -notmatch '^([A-Za-z0-9._-]+)==(.+)$') { continue }
        $out += New-Outil -Famille 'pip (utilisateur)' -Id $matches[1] -Version $matches[2] `
            -Commande "pip install $($matches[1])"
    }
    return $out
}

# « dotnet tool list -g » sort un tableau en colonnes, avec une ligne de tirets
# sous l'entete. Les colonnes sont separees par au moins deux espaces.
function Format-PaquetsDotnet {
    param([string[]]$Lignes)
    $out = @()
    foreach ($l in @($Lignes)) {
        if ([string]::IsNullOrWhiteSpace($l)) { continue }
        $t = $l.Trim()
        if ($t -match '^-+') { continue }
        if ($t -match '^(Package Id|Identifiant)') { continue }
        $cols = @($t -split '\s{2,}' | Where-Object { $_ })
        if ($cols.Count -lt 2) { continue }
        $id = $cols[0].Trim()
        # Un identifiant de paquet NuGet n'a ni espace ni caractere exotique :
        # ce filtre ecarte les lignes de texte libre que la commande imprime.
        if ($id -notmatch '^[A-Za-z0-9._-]+$') { continue }
        $out += New-Outil -Famille 'dotnet (global)' -Id $id -Version $cols[1].Trim() `
            -Commande "dotnet tool install -g $id"
    }
    return $out
}

# Les modules PowerShell installes par l'utilisateur n'apparaissent nulle part
# ailleurs : ni au registre, ni dans winget, ni dans Ajout/Suppression. Sans
# cette liste, ils se redecouvrent un par un au premier script qui echoue.
function Format-ModulesPowerShell {
    param($Modules)
    $out = @()
    foreach ($m in @($Modules)) {
        if (-not $m) { continue }
        $nom = ''
        $pn = $m.PSObject.Properties['Name']
        if ($pn) { $nom = ([string]$pn.Value).Trim() }
        if ([string]::IsNullOrWhiteSpace($nom)) { continue }
        $v = ''
        $pv = $m.PSObject.Properties['Version']
        if ($pv -and $pv.Value) { $v = [string]$pv.Value }
        $out += New-Outil -Famille 'PowerShell' -Id $nom -Version $v `
            -Commande "Install-Module $nom -Scope CurrentUser"
    }
    return $out
}

# « cargo install --list » : « nom v1.2.3:» puis les binaires, indentes.
function Format-PaquetsCargo {
    param([string[]]$Lignes)
    $out = @()
    foreach ($l in @($Lignes)) {
        if ([string]::IsNullOrWhiteSpace($l)) { continue }
        # Les binaires fournis par un paquet sont indentes : seule la ligne de
        # tete, collee a la marge, nomme le paquet a reinstaller.
        if ($l -match '^\s') { continue }
        if ($l -notmatch '^([A-Za-z0-9._-]+)\s+v([^\s:]+)') { continue }
        $out += New-Outil -Famille 'cargo' -Id $matches[1] -Version $matches[2] `
            -Commande "cargo install $($matches[1])"
    }
    return $out
}

function Read-OutilsLangages {
    Write-Host "  outils npm, pip, dotnet, PowerShell, cargo..." -NoNewline
    $out = @()
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        try { $out += @(Format-PaquetsNpm -Json (& npm ls -g --depth=0 --json 2>$null | Out-String)) } catch { }
    }
    if (Get-Command pip -ErrorAction SilentlyContinue) {
        # --not-required : sans lui, la liste se remplit des dependances
        # transitives — certifi, idna, urllib3 — que personne n'installe
        # volontairement et que pip remettra toutes seules.
        try { $out += @(Format-PaquetsPip -Lignes @(& pip list --user --not-required --format=freeze 2>$null)) } catch { }
    }
    if (Get-Command dotnet -ErrorAction SilentlyContinue) {
        try { $out += @(Format-PaquetsDotnet -Lignes @(& dotnet tool list -g 2>$null)) } catch { }
    }
    # Get-InstalledModule ne voit que ce qui vient d'une galerie : c'est
    # exactement ce qu'on veut, les modules livres avec Windows reviennent
    # seuls.
    if (Get-Command Get-InstalledModule -ErrorAction SilentlyContinue) {
        try { $out += @(Format-ModulesPowerShell -Modules (Get-InstalledModule -ErrorAction SilentlyContinue)) } catch { }
    }
    if (Get-Command cargo -ErrorAction SilentlyContinue) {
        try { $out += @(Format-PaquetsCargo -Lignes @(& cargo install --list 2>$null)) } catch { }
    }
    if (-not $out.Count) { Write-Host " aucun, ignore" -ForegroundColor Yellow; return @() }
    Write-Host " $($out.Count) outil(s)"
    return $out
}

# ---------------------------------------------------------------- configurations
#
# Installer un logiciel prend une commande winget ; retrouver ses reglages prend
# une soiree. Le scanner savait relever ce qui est installe, jamais ou vivent
# les reglages — l'onglet « Donnees » listait des chemins ecrits a la main.
#
# Cette table dit ou chaque logiciel range sa configuration. Elle est forcement
# incomplete : elle couvre ce qui revient souvent, et s'allonge d'une ligne.
# Rien n'est devine — un chemin absent de la table n'est pas cherche, et un
# chemin de la table qui n'existe pas sur la machine n'est pas retenu.
#
# `cle` vaut $null pour ce qui ne depend d'aucun logiciel installe (les cles
# SSH existent sans client SSH declare). Sinon c'est la cle normalisee du
# logiciel, celle que Get-Cle produit.
$ConfigsConnues = @(
    @{ cle=$null;              nom='Clés SSH';                chemins=@('%USERPROFILE%\.ssh');                            quoi='Clés privées et known_hosts. À traiter comme un mot de passe.' }
    @{ cle=$null;              nom='Configuration Git';       chemins=@('%USERPROFILE%\.gitconfig');                      quoi='Nom, courriel, alias, options.' }
    @{ cle=$null;              nom='Clés GPG';                chemins=@('%APPDATA%\gnupg');                               quoi='Trousseau de signature.' }
    @{ cle='visualstudiocode'; nom='Visual Studio Code';      chemins=@('%APPDATA%\Code\User');                           quoi='Réglages, raccourcis, extraits. La liste des extensions s''exporte à part.' }
    @{ cle='notepadpp';        nom='Notepad++';               chemins=@('%APPDATA%\Notepad++');                           quoi='Thème, sessions, macros.' }
    @{ cle='sublimetext';      nom='Sublime Text';            chemins=@('%APPDATA%\Sublime Text\Packages\User');          quoi='Réglages et paquets.' }
    @{ cle='autohotkey';       nom='AutoHotkey';              chemins=@('%USERPROFILE%\Documents\AutoHotkey');            quoi='Vos scripts.' }
    @{ cle='obsidian';         nom='Obsidian';                chemins=@('%APPDATA%\obsidian');                            quoi='Réglages. Les notes vivent dans vos coffres, ailleurs.' }
    @{ cle='powertoys';        nom='PowerToys';               chemins=@('%LOCALAPPDATA%\Microsoft\PowerToys');            quoi='Réglages de chaque module.' }
    @{ cle='windowsterminal';  nom='Windows Terminal';        chemins=@('%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState'); quoi='settings.json : profils, thèmes, raccourcis.' }
    # Ce qui est ecarte ici est volontairement etroit : des rapports de plantage,
    # de la telemetrie, des sauvegardes de session et des index qui se
    # reconstruisent au premier demarrage. On ne touche NI a « storage », qui
    # porte les donnees des applications web, NI aux courriels : un cache mal
    # identifie qu'on jette est une perte, pas une economie.
    @{ cle='mozillafirefox';   nom='Profils Firefox';         chemins=@('%APPDATA%\Mozilla\Firefox\Profiles');
       exclure=@('*\minidumps', '*\crashes', '*\datareporting', '*\saved-telemetry-pings',
                 '*\sessionstore-backups', '*\startupCache', '*\shader-cache',
                 '*\thumbnails', '*\weave\logs', '*\gmp-*\*\*.log');
       quoi='Marque-pages, mots de passe, extensions, cookies. Volumineux. Les rapports de plantage et la telemetrie ne suivent pas.' }
    @{ cle='mozillathunderbird';nom='Thunderbird';            chemins=@('%APPDATA%\Thunderbird\Profiles');
       exclure=@('*\minidumps', '*\crashes', '*\datareporting', '*\saved-telemetry-pings',
                 '*\sessionstore-backups', '*\startupCache',
                 '*\global-messages-db.sqlite');
       quoi='Comptes et courriels locaux. Volumineux. L''index de recherche se reconstruit tout seul et ne suit pas.' }
    @{ cle='filezilla';        nom='FileZilla';               chemins=@('%APPDATA%\FileZilla');                           quoi='Sites enregistrés. Contient des mots de passe.' }
    @{ cle='winscp';           nom='WinSCP';                  chemins=@('%APPDATA%\WinSCP.ini');                          quoi='Sessions enregistrées.' }
    # Ces cinq-la ne posent aucun fichier de reglages : tout vit dans le
    # registre. PuTTY est le cas le plus couteux — ses sessions SSH entieres,
    # hotes, ports, cles associees, sont sous SimonTatham et nulle part
    # ailleurs. La table ne connaissait que des chemins, donc ils partaient
    # en silence.
    @{ cle='putty';            nom='Sessions PuTTY';          chemins=@();
       registre=@('HKCU:\Software\SimonTatham');
       quoi='Sessions SSH enregistrées : hôtes, ports, clés associées. Rien n''est stocké en fichier.' }
    @{ cle='7zip';             nom='7-Zip';                   chemins=@();
       registre=@('HKCU:\Software\7-Zip');
       quoi='Associations de fichiers et réglages de compression.' }
    @{ cle='winrar';           nom='WinRAR';                  chemins=@('%APPDATA%\WinRAR');
       registre=@('HKCU:\Software\WinRAR');
       quoi='Réglages, et le fichier de licence rarreg.key s''il est posé à côté.' }
    @{ cle='winzip';           nom='WinZip';                  chemins=@();
       registre=@('HKCU:\Software\Nico Mak Computing\WinZip');
       quoi='Réglages et enregistrement.' }
    @{ cle='teamviewer';       nom='TeamViewer';              chemins=@();
       registre=@('HKCU:\Software\TeamViewer');
       quoi='Ordinateurs enregistrés et préférences.' }
    @{ cle='qbittorrent';      nom='qBittorrent';             chemins=@('%APPDATA%\qBittorrent','%LOCALAPPDATA%\qBittorrent'); quoi='Réglages et torrents en cours.' }
    @{ cle='obsstudio';        nom='OBS Studio';              chemins=@('%APPDATA%\obs-studio');                          quoi='Scènes, sources, profils d''encodage.' }
    @{ cle='vlcmediaplayer';   nom='VLC';                     chemins=@('%APPDATA%\vlc');                                 quoi='Réglages et équaliseur.' }
    @{ cle='krita';            nom='Krita';                   chemins=@('%APPDATA%\krita','%LOCALAPPDATA%\krita');        quoi='Brosses, espaces de travail.' }
    @{ cle='gimp';             nom='GIMP';                    chemins=@('%APPDATA%\GIMP');                                quoi='Brosses, greffons, préférences.' }
    @{ cle='blender';          nom='Blender';                 chemins=@('%APPDATA%\Blender Foundation\Blender');          quoi='Préférences, greffons, thèmes.' }
    @{ cle='unityhub';         nom='Unity';                   chemins=@('%APPDATA%\Unity','%APPDATA%\UnityHub');          quoi='Licences et réglages de l''éditeur.' }
    @{ cle='androidstudio';    nom='Android Studio';          chemins=@('%APPDATA%\Google\AndroidStudio*');               quoi='Réglages de l''IDE : raccourcis, style de code, greffons. Le dossier porte la version, et les caches vivent ailleurs.' }
    @{ cle='intellijidea';     nom='JetBrains';               chemins=@('%APPDATA%\JetBrains');                           quoi='Réglages communs aux IDE JetBrains.' }
    # Le fichier le plus coûteux à perdre de toute la table, et le plus petit.
    # Un debug.keystore ne se régénère pas à l'identique : les clés Maps,
    # Firebase et Sign-In liées à son SHA-1 cessent de fonctionner, et chaque
    # app déjà posée sur un appareil de test doit être désinstallée avant de
    # pouvoir être réinstallée. Les clés ADB évitent que chaque téléphone
    # redemande « Autoriser le débogage USB ».
    @{ cle=$null;              nom='Signature Android et clés ADB'; chemins=@('%USERPROFILE%\.android');
       exclure=@('avd', 'cache', 'build-cache', 'temp', 'breakpad');
       quoi='debug.keystore et les clés ADB. Le keystore ne se régénère pas : les clés Maps, Firebase et Sign-In cesseraient de marcher. Les émulateurs sont comptés à part.' }
    # Volumineux et facultatif, donc à part : chacun décide si recréer ses
    # appareils virtuels coûte plus cher que la place qu'ils prennent.
    @{ cle=$null;              nom='Émulateurs Android (AVD)'; chemins=@('%USERPROFILE%\.android\avd');
       quoi='Les appareils virtuels et leurs données de test. Plusieurs Go par émulateur : à emporter seulement si les recréer coûte plus cher que la place.' }
    # gradle.properties pèse deux kilo-octets et porte les réglages mémoire,
    # parfois les identifiants de signature. Le dossier caches à côté pèse des
    # Go et se régénère tout seul.
    @{ cle=$null;              nom='Gradle';                  chemins=@('%USERPROFILE%\.gradle');
       exclure=@('caches', 'daemon', 'native', 'wrapper', 'build-cache-1', 'workers', 'jdks', 'notifications', '.tmp', 'kotlin-profile');
       quoi='gradle.properties : réglages mémoire et parfois identifiants de signature. Les caches, eux, se régénèrent.' }
    @{ cle=$null;              nom='Maven';                   chemins=@('%USERPROFILE%\.m2\settings.xml');               quoi='Dépôts, miroirs et identifiants. Le dossier repository se retélécharge.' }
    @{ cle='docker';           nom='Docker Desktop';          chemins=@('%APPDATA%\Docker','%USERPROFILE%\.docker');      quoi='Réglages. Les images se retéléchargent.' }
    @{ cle='steam';            nom='Steam — sauvegardes';     chemins=@('%PROGRAMFILES(X86)%\Steam\userdata');            quoi='Sauvegardes des jeux hors cloud, et configurations de manettes.' }
    @{ cle='vortex';           nom='Vortex';                  chemins=@('%APPDATA%\Vortex');                              quoi='Profils de mods.' }
    @{ cle='icue';             nom='Corsair iCUE';            chemins=@('%APPDATA%\Corsair');                             quoi='Profils d''éclairage et macros.' }
    @{ cle='signalrgb';        nom='SignalRGB';               chemins=@('%APPDATA%\WhirlwindFX');                         quoi='Effets et agencement des appareils.' }
    @{ cle='rainmeter';        nom='Rainmeter';               chemins=@('%APPDATA%\Rainmeter','%USERPROFILE%\Documents\Rainmeter'); quoi='Habillages et dispositions.' }
    @{ cle='windhawk';         nom='Windhawk';                chemins=@('%PROGRAMDATA%\Windhawk\Engine\Mods');            quoi='Modifications installées et leurs réglages.' }
    @{ cle='sharex';           nom='ShareX';                  chemins=@('%USERPROFILE%\Documents\ShareX');                quoi='Flux de capture et destinations.' }
    @{ cle='everything';       nom='Everything';              chemins=@('%APPDATA%\Everything');                          quoi='Filtres et signets de recherche.' }
)

# Un detecteur qui echoue ne doit pas emporter le scan entier. Le script tourne
# avec $ErrorActionPreference = 'Stop' — il le faut, une erreur silencieuse
# produirait un inventaire incomplet sans le dire — mais chaque source est
# independante : winget absent, Store indisponible, Epic pas installe, ce sont
# des situations normales. Celle qui echoue le dit et laisse la place aux
# autres, comme la page isole le rendu de chaque onglet.
function Invoke-Detecteur {
    param(
        [Parameter(Mandatory)] [string] $Nom,
        [Parameter(Mandatory)] [scriptblock] $Bloc
    )
    try {
        return & $Bloc
    } catch {
        # Le Write-Host du detecteur s'est arrete en cours de ligne.
        Write-Host ""
        Write-Host ("  {0} : ignore, {1}" -f $Nom, $_.Exception.Message) -ForegroundColor Yellow
        return 0
    }
}

# Join-Path s'arrete net quand le chemin de depart est vide, et une seule
# variable d'environnement absente suffisait a faire tomber tout le scan.
function Join-CheminSur {
    param([string]$Base, [string]$Suite)
    if ([string]::IsNullOrWhiteSpace($Base)) { return $null }
    # Join-Path interprete le debut comme un nom de lecteur et s'arrete quand il
    # n'existe pas. On assemble nous-memes : ce chemin ne sert qu'a un
    # Test-Path juste apres, qui tranchera.
    # -ErrorAction Stop : sans lui l'erreur de Join-Path n'est pas bloquante,
    # le catch ne la voit pas, et la fonction rend une chaine vide.
    try {
        return (Join-Path $Base $Suite -ErrorAction Stop)
    } catch {
        return ($Base.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar + $Suite)
    }
}

# Measure-Object sur une collection vide ne renvoie aucun objet : lire .Sum
# dessus est une erreur sous Set-StrictMode, et le script s'arretait la — apres
# avoir ecrit le fichier, donc en affichant une erreur rouge sur un scan reussi.
# Le cas n'a rien d'exotique : aucune source ne donne la taille de toutes les
# applications, et certaines n'en donnent aucune.
# Compter ce qu'on a trouve, sans se tromper de forme.
#
# @($x).Count est la parade habituelle : PowerShell aplatit un tableau d'un
# seul element, et .Count echoue alors sous Set-StrictMode. Mais applique a un
# DICTIONNAIRE, @() l'enveloppe entier dans un tableau et rend 1, toujours. Le
# scan annoncait ainsi « 1 variable d'environnement relevee » quel que soit le
# nombre reel. Trouve en executant le script, pas en le relisant.
function Get-Nombre {
    param($Valeur)
    if ($null -eq $Valeur) { return 0 }
    if ($Valeur -is [System.Collections.IDictionary]) { return $Valeur.Count }
    return @($Valeur).Count
}

# Vrai si $Enfant est sous $Parent. Comparaison sur les segments, pas sur le
# texte : « D:\Outils2 » n'est pas sous « D:\Outils », meme si la chaine
# commence pareil.
function Test-SousChemin {
    param([string]$Parent, [string]$Enfant)
    if ([string]::IsNullOrWhiteSpace($Parent) -or [string]::IsNullOrWhiteSpace($Enfant)) { return $false }
    $p = (($Parent -replace '/', '\').TrimEnd('\')).ToLowerInvariant()
    $e = (($Enfant -replace '/', '\').TrimEnd('\')).ToLowerInvariant()
    if ($p -eq $e) { return $false }
    return $e.StartsWith($p + '\')
}

# Le total de ce qu'il y a a emporter, sans compter deux fois. Un gros dossier
# signale peut contenir un logiciel portable ou une cle : additionner les deux
# gonflerait le chiffre, et un chiffre presente comme « prevois tant » doit
# etre juste ou ne pas etre affiche.
# Tout ce qui porte un chemin ne se copie pas pour autant. Un cache se
# reconstruit tout seul : le compter dans le total reserverait des
# gigaoctets sur la cle pour un fichier qu'on ne copiera pas. La regle vit
# ici plutot que dans une expression au milieu de scan-pc.ps1, pour qu'elle
# soit verifiable.
function Select-AEmporter {
    param($Entrees)
    $out = @()
    foreach ($e in @($Entrees)) {
        if ($null -eq $e -or -not ($e -is [System.Collections.IDictionary])) { continue }
        if ($e.Contains('cache') -and $e['cache']) { continue }
        $out += $e
    }
    return $out
}

function Get-TotalAPrevoirMo {
    param($Groupes)
    $tout = @()
    foreach ($g in @($Groupes)) {
        foreach ($e in @($g)) {
            if ($null -eq $e -or -not ($e -is [System.Collections.IDictionary])) { continue }
            if (-not $e.Contains('chemin')) { continue }
            $mo = 0
            if ($e.Contains('tailleMo') -and $null -ne $e['tailleMo']) { $mo = [double]$e['tailleMo'] }
            elseif ($e.Contains('tailleKo') -and $null -ne $e['tailleKo']) { $mo = [double]$e['tailleKo'] / 1024 }
            $tout += [ordered]@{ chemin = [string]$e['chemin']; mo = $mo }
        }
    }
    $total = [double]0
    foreach ($e in $tout) {
        $couvert = $false
        foreach ($autre in $tout) {
            if (Test-SousChemin -Parent $autre.chemin -Enfant $e.chemin) { $couvert = $true; break }
        }
        if (-not $couvert) { $total += $e.mo }
    }
    return [math]::Round($total, 1)
}

# Ecrire un fichier texte en UTF-8 SANS marqueur d'octets.
#
# Set-Content -Encoding UTF8 en pose un sous Windows PowerShell 5.1. La page le
# tolere — le navigateur le retire en decodant — mais rien d'autre : un vrai
# inventaire produit sur une machine a fait echouer un simple ConvertFrom-Json
# hors PowerShell, et l'erreur ne parle que du marqueur, pas de la cause.
# Un fichier d'echange doit pouvoir etre relu par autre chose que nous.
function Write-TexteUtf8 {
    param([string]$Chemin, [string]$Contenu)
    [System.IO.File]::WriteAllText($Chemin, $Contenu, (New-Object System.Text.UTF8Encoding $false))
}

function Get-Somme {
    param($Elements, [string]$Propriete)
    if (-not $Elements) { return 0 }
    # Les elements du projet sont des dictionnaires ordonnes, pas des objets :
    # PSObject.Properties n'y voit rien et Measure-Object non plus. La somme
    # rendait donc 0, en silence, partout ou on l'appelait — la taille des
    # applications et celle des dossiers de configuration n'ont jamais ete
    # affichees. Trouve en ajoutant un troisieme appel qui rendait 0 lui aussi.
    $total = [double]0
    $vu = $false
    foreach ($e in @($Elements)) {
        if ($null -eq $e) { continue }
        $v = $null
        if ($e -is [System.Collections.IDictionary]) {
            if ($e.Contains($Propriete)) { $v = $e[$Propriete] }
        }
        # Sous Set-StrictMode, lire une propriete absente est deja une erreur :
        # on verifie qu'elle existe avant, plutot que de compter sur $null.
        elseif ($e.PSObject.Properties[$Propriete]) { $v = $e.$Propriete }
        if ($null -eq $v -or $v -eq '') { continue }
        $n = [double]0
        if ([double]::TryParse([string]$v, [ref]$n)) { $total += $n; $vu = $true }
    }
    if (-not $vu) { return 0 }
    return $total
}

# ---------------------------------------------------------------- exclusions
#
# La table copiait des dossiers entiers, sans exception possible. Telle quelle,
# une entree « .gradle » embarquait dix Go de caches regenerables pour deux
# kilo-octets de reglages, et une entree « .android » embarquait les emulateurs
# avec le fichier de signature. Une regle peut maintenant nommer ce qu'elle
# laisse derriere elle.
#
# Les motifs sont relatifs a la racine de l'entree, avec les jokers habituels.
# « caches » exclut le dossier et tout ce qu'il contient ; « *.log » exclut les
# fichiers correspondants.
function Test-CheminExclu {
    param([string]$Relatif, [string[]]$Motifs)
    if (-not $Motifs -or [string]::IsNullOrWhiteSpace($Relatif)) { return $false }
    $r = ($Relatif -replace '/', '\\').Trim('\\')
    foreach ($m in $Motifs) {
        if ([string]::IsNullOrWhiteSpace($m)) { continue }
        $p = ($m -replace '/', '\\').Trim('\\')
        # -like est insensible a la casse, comme les chemins de Windows.
        if ($r -like $p) { return $true }
        if ($r -like "$p\*") { return $true }
    }
    return $false
}

# Les fichiers d'un dossier, moins ce que la regle ecarte. Sert a la fois a
# annoncer une taille honnete et a copier : les deux doivent voir la meme
# chose, sinon le script annonce 2 Mo et en ecrit 10 Go.
function Get-FichiersRetenus {
    param([string]$Racine, [string[]]$Exclure)
    if (-not (Test-Path -LiteralPath $Racine)) { return @() }
    $item = Get-Item -LiteralPath $Racine -Force -ErrorAction SilentlyContinue
    if (-not $item) { return @() }
    if (-not $item.PSIsContainer) { return @($item) }
    $base = $item.FullName.TrimEnd('\', '/')
    # -ErrorAction SilentlyContinue : un sous-dossier protege ne doit pas
    # arreter le parcours, il fausse seulement son propre compte.
    return @(Get-ChildItem -LiteralPath $Racine -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object {
            $rel = $_.FullName.Substring($base.Length)
            -not (Test-CheminExclu -Relatif $rel -Motifs $Exclure)
        })
}

# Un chemin de la table peut porter un joker : Android Studio et les IDE
# JetBrains rangent leurs reglages dans un dossier qui porte leur version.
# On rend le chemin reel ET le modele correspondant, puisque c'est le modele
# qui permettra de restaurer sous un autre nom d'utilisateur.
function Expand-CheminModele {
    param([string]$Modele)
    if ([string]::IsNullOrWhiteSpace($Modele)) { return @() }
    if ($Modele -notlike '*`**') {
        $c = [Environment]::ExpandEnvironmentVariables($Modele)
        if ($c -like '*%*') { return @() }
        if (-not (Test-Path -LiteralPath $c)) { return @() }
        return @([ordered]@{ chemin = $c; modele = $Modele })
    }
    $motif = [Environment]::ExpandEnvironmentVariables($Modele)
    if ($motif -like '*%*') { return @() }
    # Tout ce qui precede le premier segment a joker est fixe : c'est lui qui
    # permet de reconstruire le modele de chaque resultat.
    $segments = $Modele -split '\\'
    $i = 0
    while ($i -lt $segments.Count -and $segments[$i] -notlike '*`**') { $i++ }
    if ($i -eq 0) { return @() }
    $prefixeModele = ($segments[0..($i - 1)] -join '\')
    $prefixe = [Environment]::ExpandEnvironmentVariables($prefixeModele).TrimEnd('\', '/')
    if ($prefixe -like '*%*') { return @() }
    $out = @()
    foreach ($m in @(Get-Item -Path $motif -Force -ErrorAction SilentlyContinue)) {
        $reste = $m.FullName.Substring($prefixe.Length).Trim('\', '/')
        $out += [ordered]@{ chemin = $m.FullName; modele = ($prefixeModele.TrimEnd('\') + '\' + $reste) }
    }
    return $out
}

function Get-TailleDossier {
    param([string]$Chemin, [string[]]$Exclure)
    try {
        if (-not (Test-Path -LiteralPath $Chemin)) { return $null }
        $item = Get-Item -LiteralPath $Chemin -Force -ErrorAction Stop
        if (-not $item.PSIsContainer) { return [math]::Round($item.Length / 1MB, 2) }
        # La taille annoncee doit etre celle de ce qui sera copie, exclusions
        # comprises : annoncer 10 Go pour en ecrire 2 Mo se remarquerait, mais
        # l'inverse se remarquerait au pire moment.
        $somme = Get-Somme (Get-FichiersRetenus -Racine $Chemin -Exclure $Exclure) 'Length'
        if (-not $somme) { return 0 }
        return [math]::Round($somme / 1MB, 2)
    } catch { return $null }
}

# Certains logiciels ne posent aucun fichier de reglages : tout vit dans le
# registre. PuTTY y range ses sessions SSH entieres, sous
# HKCU\Software\SimonTatham ; 7-Zip, WinRAR, WinZip et TeamViewer font pareil.
# La table ne connaissait que des chemins de fichiers, donc ces reglages
# partaient en silence : rien n'echouait, ils n'etaient simplement jamais vus.
#
# On ne lit pas la cle ici — sa copie est le travail de sauvegarder-configs.ps1,
# qui l'exporte en .reg. On constate seulement qu'elle existe, pour ne pas
# proposer d'emporter les reglages d'un logiciel qui n'en a jamais pose.
function Test-CleRegistre {
    param([string]$Cle)
    if ([string]::IsNullOrWhiteSpace($Cle)) { return $false }
    # Hors de Windows il n'y a pas de registre : le lecteur HKCU: n'existe pas,
    # et Test-Path rend $false sans jeter. C'est ce qu'on veut.
    try { return [bool](Test-Path -LiteralPath $Cle -ErrorAction SilentlyContinue) }
    catch { return $false }
}

function Read-Configs {
    param([string[]]$ClesInstallees = @())
    Write-Host "  dossiers de configuration..." -NoNewline
    $trouves = @()
    foreach ($regle in $ConfigsConnues) {
        # Une regle rattachee a un logiciel ne s'applique que s'il est installe :
        # sinon on proposerait d'emporter les restes d'un logiciel desinstalle.
        if ($regle.cle -and ($ClesInstallees -notcontains $regle.cle)) { continue }
        $exclure = @()
        if ($regle.Contains('exclure') -and $regle.exclure) { $exclure = @($regle.exclure) }
        foreach ($brut in $regle.chemins) {
            # Expand-CheminModele rend le chemin reel ET le modele : le chemin
            # AVANT expansion, « %APPDATA%\Code\User », vaut sur n'importe
            # quelle machine la ou « C:\Users\antoni\... » ne vaut que sur
            # celle-ci. C'est lui qui permet de restaurer sous un autre nom
            # d'utilisateur. Un joker peut rendre plusieurs resultats.
            foreach ($r in @(Expand-CheminModele -Modele $brut)) {
                $trouves += [ordered]@{
                    nom      = $regle.nom
                    chemin   = $r.chemin
                    modele   = $r.modele
                    quoi     = $regle.quoi
                    # Ce que la regle laisse derriere elle, relatif a sa racine.
                    exclure  = $exclure
                    tailleMo = Get-TailleDossier -Chemin $r.chemin -Exclure $exclure
                    logiciel = $regle.cle
                }
            }
        }

        # Les cles de registre declarees par la regle. Une entree de registre
        # n'a ni taille ni contenu mesurable a ce stade : on la marque, et
        # sauvegarder-configs.ps1 l'exportera en .reg.
        if ($regle.Contains('registre') -and $regle.registre) {
            foreach ($cleReg in @($regle.registre)) {
                if (-not (Test-CleRegistre -Cle $cleReg)) { continue }
                $trouves += [ordered]@{
                    nom      = $regle.nom
                    chemin   = $cleReg
                    modele   = $cleReg
                    quoi     = $regle.quoi
                    exclure  = @()
                    tailleMo = $null
                    logiciel = $regle.cle
                    # Ce marqueur dit a la sauvegarde d'exporter plutot que de
                    # copier, et a la page d'afficher une cle et non un dossier.
                    registre = $true
                }
            }
        }
    }
    Write-Host " $(@($trouves).Count) trouve(s)"
    return $trouves
}

# ---------------------------------------------------------- fichiers ouverts
#
# Copy-Item echoue sur un fichier verrouille. Firefox et Thunderbird en
# ouverture gardent la main sur places.sqlite, cookies.sqlite et key4.db —
# c'est-a-dire les marque-pages et les mots de passe, exactement ce qu'on
# venait chercher. La sauvegarde signalait l'echec fichier par fichier, noye
# au milieu du reste, et personne ne faisait le lien avec le navigateur reste
# ouvert derriere.
#
# On ne ferme rien a la place de l'utilisateur : fermer un navigateur sous les
# doigts de quelqu'un est le genre d'initiative qu'un script n'a pas a prendre.
# On le previent avant de copier.

# Quels processus tiennent quels reglages. Le nom est celui du processus, sans
# .exe, tel que Get-Process le rend.
$ProcessusVerrouillants = @{
    'firefox'     = 'Profils Firefox'
    'thunderbird' = 'Thunderbird'
    'chrome'      = 'Google Chrome'
    'msedge'      = 'Microsoft Edge'
    'Code'        = 'Visual Studio Code'
    'obsidian'    = 'Obsidian'
    'qbittorrent' = 'qBittorrent'
    'Discord'     = 'Discord'
}

# Rend les noms lisibles des logiciels ouverts qui verrouillent une des
# configurations qu'on s'apprete a copier. Prend la liste des noms de
# configurations retenues, pour ne prevenir que de ce qui concerne cette copie.
function Get-LogicielsAFermer {
    param(
        [string[]]$NomsConfigs = @(),
        # Injectable pour le test : sans ca, il faudrait lancer Firefox.
        $Processus = $null
    )
    $ouverts = @()
    if ($null -eq $Processus) {
        try { $Processus = @(Get-Process -ErrorAction SilentlyContinue) } catch { $Processus = @() }
    }
    $nomsVus = @{}
    foreach ($p in @($Processus)) {
        if (-not $p) { continue }
        $n = ''
        $pn = $p.PSObject.Properties['ProcessName']
        if ($pn) { $n = [string]$pn.Value }
        if ([string]::IsNullOrWhiteSpace($n)) { continue }
        if (-not $ProcessusVerrouillants.ContainsKey($n)) { continue }
        $config = $ProcessusVerrouillants[$n]
        # On ne previent que pour ce qui est effectivement dans la copie.
        if ($NomsConfigs.Count -and ($NomsConfigs -notcontains $config)) { continue }
        if ($nomsVus.ContainsKey($config)) { continue }
        $nomsVus[$config] = $true
        $ouverts += $config
    }
    return @($ouverts)
}

# ---------------------------------------------------------------- materiel
#
# Le bloc « Ma configuration » de la page attendait une saisie a la main. Or
# Windows connait deja tout ca. On le lui demande.
#
# La lecture (CIM) et la mise en forme sont separees : la lecture ne tourne que
# sous Windows, la mise en forme se teste partout. C'est elle qui decide de ce
# qui s'affiche, donc c'est elle qu'il faut pouvoir verifier.

function Format-Materiel {
    param($CarteMere, $Processeur, $Cartes, $Barrettes, $Disques)

    $config = [ordered]@{}

    if ($CarteMere) {
        $bouts = @($CarteMere.Manufacturer, $CarteMere.Product) |
                 Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        if ($bouts) { $config['cm'] = ($bouts -join ' ').Trim() }
    }

    if ($Processeur) {
        $nom = @($Processeur)[0].Name
        # « AMD Ryzen 7 9800X3D 8-Core Processor » : la fin n'apprend rien.
        if ($nom) { $config['cpu'] = ($nom -replace '\s*\d+-Core Processor\s*$', '').Trim() }
    }

    if ($Cartes) {
        # Les affichages virtuels et le pilote de base de Windows ne sont pas
        # des cartes graphiques : les nommer enverrait chercher leur pilote.
        $vraies = @($Cartes | Where-Object {
            $_.Name -and $_.Name -notmatch 'Basic Display|Remote Display|Virtual|Parsec|IddSample'
        })
        if ($vraies.Count) { $config['gpu'] = (@($vraies)[0].Name).Trim() }
    }

    if ($Barrettes) {
        $octets = Get-Somme $Barrettes 'Capacity'
        $go = if ($octets) { [math]::Round($octets / 1GB, 0) } else { 0 }
        $vitesses = @($Barrettes | Where-Object {
            $_.PSObject.Properties['ConfiguredClockSpeed'] -and $_.ConfiguredClockSpeed
        } | ForEach-Object { $_.ConfiguredClockSpeed })
        $type = @($Barrettes | Where-Object {
            $_.PSObject.Properties['SMBIOSMemoryType'] -and $_.SMBIOSMemoryType
        } | ForEach-Object { $_.SMBIOSMemoryType } | Select-Object -First 1)
        # Indexer un tableau vide jette : les barrettes ne declarent pas toutes
        # leur type, et certaines machines n'en declarent aucune.
        $nomType = ''
        if (@($type).Count -gt 0) {
            $nomType = switch (@($type)[0]) { 26 { 'DDR4' } 34 { 'DDR5' } default { '' } }
        }
        $bouts = @()
        if ($go) { $bouts += "$go Go" }
        if ($nomType) { $bouts += $nomType }
        if ($vitesses) { $bouts += ((@($vitesses) | Measure-Object -Maximum).Maximum.ToString() + ' MT/s') }
        if ($bouts) { $config['ram'] = ($bouts -join ' ') }
    }

    if ($Disques) {
        # Le disque systeme d'abord : c'est celui qu'on remplace ou qu'on garde.
        $tries = @($Disques | Sort-Object -Property Size -Descending)
        $principal = if ($tries.Count -gt 0) { $tries[0] } else { $null }
        if ($principal -and $principal.PSObject.Properties['Model'] -and $principal.Model) {
            $modele = $principal.Model.Trim()
            $go = 0
            if ($principal.PSObject.Properties['Size'] -and $principal.Size) {
                $go = [math]::Round($principal.Size / 1GB, 0)
            }
            # « Samsung SSD 9100 PRO 2TB 1863 Go » dit deux fois la meme chose :
            # on n'ajoute la taille que si le modele ne la porte pas deja.
            $dejaDite = ($modele -match '\d+\s*(To|TB|Go|GB)\b')
            $config['ssd'] = if ($go -and -not $dejaDite) { "$modele $go Go" } else { $modele }
        }
    }

    return $config
}

function Read-Materiel {
    Write-Host "  materiel..." -NoNewline
    $config = [ordered]@{}
    try {
        $config = Format-Materiel `
            -CarteMere  (Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue) `
            -Processeur (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue) `
            -Cartes     (Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue) `
            -Barrettes  (Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue) `
            -Disques    (Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue)
    } catch {
        Write-Host " indisponible, ignore" -ForegroundColor Yellow
        return [ordered]@{}
    }
    Write-Host " $(@($config.Keys).Count) composant(s)"
    return $config
}

# ---------------------------------------------------------------- controles
#
# Quatre questions a poser a une machine NEUVE, et a elle seule. Elles ne
# disent pas ce qu'il faut reinstaller : elles disent si la machine qu'on vient
# de recevoir est bien celle qu'on a payee, et si elle est correctement reglee.
# Aucune ne se voit a l'oeil nu, et les quatre se decouvrent trop tard.
#
# Chaque controle rend le meme objet : un constat, un etat, et ce que ca change.
# « inconnu » n'est pas un echec : beaucoup de ces informations demandent les
# droits administrateur ou un materiel qui les declare. Dire « je ne sais pas »
# vaut mieux que dire « tout va bien » sans avoir regarde.

function New-Controle {
    param([string]$Nom, [string]$Etat, [string]$Constat, [string]$Quoi)
    return [ordered]@{ nom = $Nom; etat = $Etat; constat = $Constat; quoi = $Quoi }
}

# 1. La memoire tourne-t-elle a sa vitesse nominale ?
#
# Une barrette DDR5-6000 posee sur une carte mere sortie d'usine tourne a
# 4800 : le profil XMP (Intel) ou EXPO (AMD) n'est pas active tant que personne
# ne l'a active dans le BIOS. Rien ne le signale, la machine marche, et on perd
# 10 a 15 % de performances pendant des annees. C'est l'erreur d'assemblage la
# plus repandue, y compris chez des assembleurs professionnels.
#
# Win32_PhysicalMemory porte les deux chiffres : Speed est ce que la barrette
# sait faire, ConfiguredClockSpeed ce qu'elle fait vraiment.
function Format-ControleMemoire {
    param($Barrettes)
    $b = @($Barrettes | Where-Object { $_ })
    if (-not $b.Count) {
        return New-Controle -Nom 'Vitesse de la mémoire' -Etat 'inconnu' `
            -Constat 'Aucune barrette ne se déclare.' `
            -Quoi 'À vérifier dans le BIOS, ou avec un outil dédié.'
    }
    $nominale = 0
    $reelle = 0
    foreach ($m in $b) {
        $ps = $m.PSObject.Properties['Speed']
        $pc = $m.PSObject.Properties['ConfiguredClockSpeed']
        if ($ps -and $ps.Value) { $v = [int]$ps.Value; if ($v -gt $nominale) { $nominale = $v } }
        if ($pc -and $pc.Value) { $v = [int]$pc.Value; if ($v -gt $reelle)   { $reelle   = $v } }
    }
    if (-not $nominale -or -not $reelle) {
        return New-Controle -Nom 'Vitesse de la mémoire' -Etat 'inconnu' `
            -Constat 'Les barrettes ne déclarent pas leur vitesse.' `
            -Quoi 'À vérifier dans le BIOS : cherche XMP (Intel) ou EXPO (AMD).'
    }
    if ($reelle -lt $nominale) {
        return New-Controle -Nom 'Vitesse de la mémoire' -Etat 'attention' `
            -Constat "La mémoire tourne à $reelle MHz alors qu'elle sait faire $nominale MHz." `
            -Quoi "Le profil XMP (Intel) ou EXPO (AMD) n'est pas activé dans le BIOS. Rien ne le signale, la machine marche, et tu perds 10 à 15 % de performances. Une case à cocher dans le BIOS."
    }
    return New-Controle -Nom 'Vitesse de la mémoire' -Etat 'ok' `
        -Constat "La mémoire tourne à $reelle MHz, sa vitesse nominale." `
        -Quoi 'Rien à faire.'
}

# 2. TRIM est-il actif ?
#
# Sans TRIM, un SSD ralentit durablement au fil des ecritures. Windows l'active
# seul dans l'immense majorite des cas ; il arrive qu'un utilitaire
# d'« optimisation » le coupe. La valeur de registre vaut 0 quand TRIM est
# actif, et son absence veut dire la meme chose : c'est le defaut de Windows.
function Format-ControleTrim {
    param($Valeur)
    if ($null -eq $Valeur) {
        return New-Controle -Nom 'TRIM du SSD' -Etat 'ok' `
            -Constat 'TRIM est actif (réglage par défaut de Windows).' `
            -Quoi 'Rien à faire.'
    }
    $n = 0
    if (-not [int]::TryParse([string]$Valeur, [ref]$n)) {
        return New-Controle -Nom 'TRIM du SSD' -Etat 'inconnu' `
            -Constat 'Le réglage est illisible.' `
            -Quoi 'À vérifier : fsutil behavior query DisableDeleteNotify'
    }
    if ($n -eq 0) {
        return New-Controle -Nom 'TRIM du SSD' -Etat 'ok' `
            -Constat 'TRIM est actif.' -Quoi 'Rien à faire.'
    }
    return New-Controle -Nom 'TRIM du SSD' -Etat 'attention' `
        -Constat 'TRIM est désactivé.' `
        -Quoi "Un SSD sans TRIM ralentit durablement au fil des écritures. À réactiver : fsutil behavior set DisableDeleteNotify 0"
}

# 3. Secure Boot et TPM.
#
# Les deux conditionnent Windows 11 et le chiffrement BitLocker. Une machine
# livree en mode Legacy ou avec le TPM desactive dans le BIOS demarre tres bien
# et se retrouve bloquee a la premiere mise a jour majeure.
function Format-ControleDemarrage {
    param($SecureBoot, $Tpm)
    $bouts = @()
    $souci = $false
    $inconnu = $false

    if ($null -eq $SecureBoot) { $bouts += 'Secure Boot : indéterminé'; $inconnu = $true }
    elseif ($SecureBoot)       { $bouts += 'Secure Boot actif' }
    else                       { $bouts += 'Secure Boot inactif'; $souci = $true }

    if ($null -eq $Tpm) { $bouts += 'TPM : indéterminé'; $inconnu = $true }
    else {
        $pres = $false
        $pp = $Tpm.PSObject.Properties['IsEnabled_InitialValue']
        if ($pp -and $pp.Value) { $pres = $true }
        $ver = ''
        $pv = $Tpm.PSObject.Properties['SpecVersion']
        if ($pv -and $pv.Value) { $ver = (([string]$pv.Value) -split ',')[0].Trim() }
        if ($pres) { $bouts += ("TPM actif" + $(if ($ver) { " (version $ver)" } else { '' })) }
        else       { $bouts += 'TPM présent mais inactif'; $souci = $true }
    }

    $etat = if ($souci) { 'attention' } elseif ($inconnu) { 'inconnu' } else { 'ok' }
    $quoi = if ($souci) {
        "Windows 11 et BitLocker en dépendent. Les deux s'activent dans le BIOS. Une machine livrée comme ça démarre très bien et se bloque à la première grosse mise à jour."
    } elseif ($inconnu) {
        "Relance ce script en tant qu'administrateur pour obtenir la réponse."
    } else { 'Rien à faire.' }

    return New-Controle -Nom 'Secure Boot et TPM' -Etat $etat -Constat ($bouts -join ' · ') -Quoi $quoi
}

# 4. Le disque est-il reellement neuf ?
#
# Le controle qui rapporte le plus. Un SSD annonce neuf avec 400 heures au
# compteur ne l'est pas : c'est un disque de retour, de demonstration, ou
# recupere. Le compteur d'heures d'allumage ne se remet pas a zero.
#
# Quelques heures sont normales : l'assemblage, les tests, l'installation de
# Windows. Au-dela d'une journee cumulee, il y a une question a poser.
function Format-ControleDisques {
    param($Compteurs, [int]$SeuilHeures = 50)
    $c = @($Compteurs | Where-Object { $_ })
    if (-not $c.Count) {
        return New-Controle -Nom 'Usure des disques' -Etat 'inconnu' `
            -Constat "Les disques ne rendent pas leur compteur d'heures." `
            -Quoi "Souvent parce que le script n'est pas lancé en administrateur. Sinon, le disque ne le déclare pas."
    }
    $suspects = @()
    $vus = @()
    foreach ($d in $c) {
        $ph = $d.PSObject.Properties['PowerOnHours']
        if (-not $ph -or $null -eq $ph.Value) { continue }
        $h = [int]$ph.Value
        $nom = 'disque'
        $pn = $d.PSObject.Properties['DeviceId']
        if ($pn -and $pn.Value) { $nom = "disque $($pn.Value)" }
        $vus += "$nom : $h h"
        if ($h -gt $SeuilHeures) { $suspects += "$nom ($h heures)" }
    }
    if (-not $vus.Count) {
        return New-Controle -Nom 'Usure des disques' -Etat 'inconnu' `
            -Constat "Aucun disque ne rend son compteur d'heures." `
            -Quoi "Souvent parce que le script n'est pas lancé en administrateur."
    }
    if ($suspects.Count) {
        return New-Controle -Nom 'Usure des disques' -Etat 'attention' `
            -Constat ("Compteur élevé sur : " + ($suspects -join ', ') + ".") `
            -Quoi "Sur une machine neuve, quelques heures sont normales : assemblage, tests, installation. Au-delà, le disque a déjà servi — retour, démonstration, ou récupéré. Le compteur ne se remet pas à zéro. Question à poser au vendeur maintenant, pas dans six mois."
    }
    return New-Controle -Nom 'Usure des disques' -Etat 'ok' `
        -Constat (($vus -join ' · ') + ".") `
        -Quoi "Compatible avec une machine neuve."
}

function Read-Controles {
    Write-Host "  controles machine..." -NoNewline
    $out = @()

    $barrettes = try { Get-CimInstance Win32_PhysicalMemory -ErrorAction Stop } catch { $null }
    $out += Format-ControleMemoire -Barrettes $barrettes

    # Le registre plutot que fsutil : la sortie de fsutil est traduite, donc
    # illisible de facon portable. La valeur, elle, ne l'est pas.
    $trim = $null
    try {
        $k = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -ErrorAction Stop
        $pv = $k.PSObject.Properties['DisableDeleteNotify']
        if ($pv) { $trim = $pv.Value }
    } catch { }
    $out += Format-ControleTrim -Valeur $trim

    # Confirme-SecureBootUEFI jette sur une machine en BIOS Legacy et sans les
    # droits administrateur : les deux cas rendent « indetermine », pas « non ».
    $sb = $null
    try { $sb = [bool](Confirm-SecureBootUEFI -ErrorAction Stop) } catch { $sb = $null }
    $tpm = $null
    try {
        $tpm = Get-CimInstance -Namespace 'root\cimv2\security\microsofttpm' -ClassName Win32_Tpm -ErrorAction Stop |
               Select-Object -First 1
    } catch { $tpm = $null }
    $out += Format-ControleDemarrage -SecureBoot $sb -Tpm $tpm

    $compteurs = @()
    try {
        $compteurs = @(Get-PhysicalDisk -ErrorAction Stop | ForEach-Object {
            $d = $_
            $r = $null
            try { $r = $d | Get-StorageReliabilityCounter -ErrorAction Stop } catch { }
            if ($r) {
                $r | Add-Member -NotePropertyName DeviceId -NotePropertyValue $d.FriendlyName -Force -PassThru
            }
        })
    } catch { $compteurs = @() }
    $out += Format-ControleDisques -Compteurs $compteurs

    $soucis = @($out | Where-Object { $_.etat -eq 'attention' }).Count
    if ($soucis) { Write-Host " $soucis point(s) a regarder" -ForegroundColor Yellow }
    else { Write-Host " $($out.Count) controle(s)" }
    return $out
}

# ---------------------------------------------------------------- licences
#
# Le fait de migration le plus couteux a decouvrir trop tard, et le moins
# visible : une licence Windows OEM est attachee a la carte mere de l'ancien
# PC. Elle ne suit pas. Une licence Retail suit. La checklist ne posait meme
# pas la question, et personne ne la pose avant d'avoir demonte la machine.
#
# La classe WMI SoftwareLicensingProduct dit tout ce qu'il faut sans toucher a
# un secret. PartialProductKey ne rend que les cinq derniers caracteres de la
# cle : c'est ce que Windows affiche lui-meme dans ses parametres, ca ne
# reinstalle rien et ca ne s'envoie nulle part. La vraie cle OEM, gravee dans
# l'UEFI, est lisible par ailleurs — elle n'a rien a faire dans un inventaire
# qu'on se transmet par cle USB, et ce script ne la lit pas.

# Les canaux que Windows declare, traduits en ce que ca change pour toi.
$CanauxLicence = @{
    'OEM'       = @{ suit = $false; quoi = "Attachee a la carte mere de cet ordinateur. Elle ne suit pas sur une machine neuve : prevois une licence." }
    'OEM_DM'    = @{ suit = $false; quoi = "Attachee a la carte mere de cet ordinateur. Elle ne suit pas sur une machine neuve : prevois une licence." }
    'OEM_SLP'   = @{ suit = $false; quoi = "Attachee a la carte mere de cet ordinateur. Elle ne suit pas sur une machine neuve : prevois une licence." }
    'Retail'    = @{ suit = $true;  quoi = "Achetee separement : transferable sur la nouvelle machine. Delie-la de l'ancienne avant de la demonter." }
    'Volume'    = @{ suit = $true;  quoi = "Licence en volume, gerée par une organisation. Vois avec celui qui l'administre." }
    'Volume:GVLK' = @{ suit = $true; quoi = "Licence en volume, gerée par une organisation. Vois avec celui qui l'administre." }
    'Volume:MAK'  = @{ suit = $true; quoi = "Licence en volume, gerée par une organisation. Vois avec celui qui l'administre." }
}

# LicenseStatus est un entier ; seul 1 veut dire « activee ».
$EtatsLicence = @{
    0 = 'non licencie'
    1 = 'active'
    2 = 'periode de grace'
    3 = 'grace hors tolerance'
    4 = 'grace non authentique'
    5 = 'notification'
    6 = 'grace prolongee'
}

function Format-Licences {
    param($Produits)
    $out = @()
    foreach ($p in @($Produits)) {
        if (-not $p) { continue }
        # Sans cle partielle, l'entree decrit un produit installable mais non
        # licencie : la liste en contient des dizaines, elles n'apprennent rien.
        $cle = ''
        $pc = $p.PSObject.Properties['PartialProductKey']
        if ($pc) { $cle = [string]$pc.Value }
        if ([string]::IsNullOrWhiteSpace($cle)) { continue }

        $nom = ''
        $pn = $p.PSObject.Properties['Name']
        if ($pn) { $nom = [string]$pn.Value }
        if ([string]::IsNullOrWhiteSpace($nom)) { continue }

        $canal = ''
        $pk = $p.PSObject.Properties['ProductKeyChannel']
        if ($pk) { $canal = ([string]$pk.Value).Trim() }

        $etat = ''
        $ps = $p.PSObject.Properties['LicenseStatus']
        if ($ps -and $null -ne $ps.Value) {
            $n = 0
            if ([int]::TryParse([string]$ps.Value, [ref]$n) -and $EtatsLicence.ContainsKey($n)) { $etat = $EtatsLicence[$n] }
        }

        $suit = $null
        $quoi = "Canal inconnu : verifie dans Parametres > Systeme > Activation si la licence est liee a ton compte Microsoft."
        if ($canal -and $CanauxLicence.ContainsKey($canal)) {
            $suit = $CanauxLicence[$canal].suit
            $quoi = $CanauxLicence[$canal].quoi
        }

        $out += [ordered]@{
            nom        = $nom.Trim()
            canal      = $canal
            etat       = $etat
            # Cinq derniers caracteres, ce que Windows affiche lui-meme.
            clePartielle = $cle.Trim()
            suitLeMateriel = $suit
            quoi       = $quoi
        }
    }
    return $out
}

function Read-Licences {
    Write-Host "  licences..." -NoNewline
    $produits = $null
    try {
        $produits = Get-CimInstance -ClassName SoftwareLicensingProduct -ErrorAction Stop |
            Where-Object { $_.PartialProductKey }
    } catch {
        Write-Host " indisponible, ignore" -ForegroundColor Yellow
        return @()
    }
    $out = @(Format-Licences -Produits $produits)
    if (-not $out.Count) { Write-Host " aucune licence lisible" -ForegroundColor Yellow; return @() }
    Write-Host " $($out.Count) licence(s)"
    return $out
}

# ------------------------------------------------ logiciels sous licence
#
# Un logiciel gratuit se reinstalle d'une commande. Un logiciel payant se
# reinstalle de la meme commande, et refuse ensuite de demarrer sans sa cle.
# Rien dans le registre ne distingue les deux : ni le prix, ni la licence n'y
# figurent. Ce qu'on peut faire, c'est tenir la liste des logiciels dont on
# sait qu'ils reclament quelque chose, et le dire avant le formatage plutot
# qu'apres.
#
# La liste est ecrite a la main, donc incomplete par construction. Elle ne
# mentira pas pour autant : une ligne absente ne veut pas dire « gratuit »,
# elle veut dire « je ne sais pas », et la page le formule ainsi. On ne marque
# que ce dont on est sur, jamais par famille d'editeur — « Microsoft » couvre
# aussi bien Office que le Visual C++ Redistributable.
$LogicielsPayants = @(
    @{ motif = 'microsoft (office|365)|^office (professional|home|standard|famille)|\bmicrosoft (word|excel|powerpoint|outlook|access|publisher|visio|project)\b'
       quoi  = "Cle Office ou abonnement Microsoft 365. Elle est dans ton compte Microsoft : verifie que tu y as acces avant de formater." }
    @{ motif = 'adobe|acrobat pro|photoshop|illustrator|premiere pro|after effects|lightroom|indesign'
       quoi  = "Abonnement Adobe : la reinstallation passe par Creative Cloud et ton identifiant. Le nombre de postes est limite, deconnecte l'ancien avant de le demonter." }
    @{ motif = 'winrar'
       quoi  = "Licence WinRAR : un fichier rarreg.key a recopier, sinon la version d'essai reprend." }
    @{ motif = 'kaspersky|bitdefender|\beset\b|norton|mcafee|avast premium|avg internet|f-secure|trend micro|malwarebytes premium'
       quoi  = "Antivirus payant : l'abonnement se rattache a un compte ou a une cle, et souvent a un nombre de postes. Retrouve-la avant de desinstaller." }
    @{ motif = 'jetbrains|intellij idea ultimate|pycharm professional|phpstorm|webstorm|rider|clion|datagrip|rubymine'
       quoi  = "Licence JetBrains : rattachee a ton compte, elle se recupere en te connectant. Verifie que tu connais le compte." }
    @{ motif = 'sublime text|sublime merge'
       quoi  = "Licence Sublime : une cle de texte, dans le courriel d'achat. Elle ne se retrouve pas autrement." }
    @{ motif = 'vmware workstation|vmware fusion|parallels desktop'
       quoi  = "Licence de virtualisation : une cle par machine. Note-la avant, les machines virtuelles ne s'ouvriront pas sans." }
    @{ motif = 'autodesk|autocad|revit|3ds max|\bmaya\b'
       quoi  = "Abonnement Autodesk : rattache a un compte, avec un nombre de postes limite. Delie l'ancien poste." }
    @{ motif = 'matlab|mathematica|\bstata\b|\bspss\b'
       quoi  = "Licence scientifique, souvent nominative ou fournie par une ecole : verifie comment tu la reactives avant de formater." }
    @{ motif = 'beyond compare|araxis merge'
       quoi  = "Licence de comparaison de fichiers : une cle dans le courriel d'achat, parfois un fichier a recopier." }
    @{ motif = 'affinity (photo|designer|publisher)|\bcapture one\b|\bdxo\b'
       quoi  = "Licence achetee une fois : elle vit dans un espace client. Verifie que tu peux encore t'y connecter." }
    @{ motif = 'camtasia|snagit|techsmith'
       quoi  = "Licence TechSmith : une cle par produit, dans ton compte TechSmith." }
    @{ motif = 'ableton|fl studio|cubase|\bstudio one\b|reaper|\bnative instruments\b'
       quoi  = "Licence audio : souvent liee a un compte ou a une cle materielle. Les projets ne s'ouvriront pas sans les memes extensions." }
    @{ motif = 'total commander|directory opus|xyplorer'
       quoi  = "Licence de gestionnaire de fichiers : une cle ou un fichier de licence a recopier." }
    @{ motif = 'internet download manager|\bidm\b|\bwinzip\b|\bnitro pro\b|pdf-xchange'
       quoi  = "Licence achetee : une cle a retrouver dans le courriel d'achat ou l'espace client." }
)

function Get-LicenceAPrevoir {
    param([string]$Nom, [string]$Editeur = '')
    if ([string]::IsNullOrWhiteSpace($Nom)) { return '' }
    $sujet = ("$Nom $Editeur").ToLowerInvariant()
    foreach ($r in $LogicielsPayants) {
        if ($sujet -match $r.motif) { return $r.quoi }
    }
    return ''
}

# Certains de ces logiciels rangent leur licence dans un fichier, en clair, a
# un endroit connu. Ce fichier ne se reconstitue pas : perdu, il faut repasser
# par l'editeur. On releve son CHEMIN, jamais son contenu — l'inventaire voyage
# sur une cle USB, et une cle de licence lisible dedans serait une cle de
# licence perdue. Le nom dans l'inventaire, le secret dans le fichier que
# l'utilisateur copie lui-meme : c'est la regle du projet partout ailleurs.
$FichiersLicence = @(
    @{ nom = 'WinRAR'; quoi = "Sans ce fichier, WinRAR redevient une version d'essai."
       chemins = @('%APPDATA%\WinRAR\rarreg.key', '%PROGRAMFILES%\WinRAR\rarreg.key', '%PROGRAMFILES(X86)%\WinRAR\rarreg.key') }
    @{ nom = 'Total Commander'; quoi = 'Le fichier de licence, a reposer a cote du programme.'
       chemins = @('%PROGRAMFILES%\totalcmd\wincmd.key', '%PROGRAMFILES(X86)%\totalcmd\wincmd.key') }
    @{ nom = 'Beyond Compare'; quoi = 'Le fichier de licence, a reposer au meme endroit.'
       chemins = @('%APPDATA%\Scooter Software\Beyond Compare *\BCLicense') }
    @{ nom = 'Sublime Text'; quoi = 'La licence, dans un fichier que la reinstallation ne recree pas.'
       chemins = @('%APPDATA%\Sublime Text*\Local\License.sublime_license') }
    @{ nom = 'Sublime Merge'; quoi = 'La licence, dans un fichier que la reinstallation ne recree pas.'
       chemins = @('%APPDATA%\Sublime Merge\Local\License.sublime_license') }
    @{ nom = 'XYplorer'; quoi = 'Le fichier de licence, a cote du programme.'
       chemins = @('%APPDATA%\XYplorer\*.lic') }
)

function Read-FichiersLicence {
    Write-Host "  fichiers de licence..." -NoNewline
    $out = @()
    foreach ($regle in $FichiersLicence) {
        foreach ($modele in @($regle.chemins)) {
            foreach ($r in @(Expand-CheminModele -Modele $modele)) {
                if (Test-Path -LiteralPath $r.chemin -PathType Container) { continue }
                $ko = $null
                try {
                    $f = Get-Item -LiteralPath $r.chemin -Force -ErrorAction Stop
                    $ko = [math]::Round($f.Length / 1KB, 1)
                } catch { }
                $out += [ordered]@{
                    nom      = $regle.nom
                    chemin   = $r.chemin
                    modele   = $r.modele
                    quoi     = $regle.quoi
                    tailleKo = $ko
                    # Ce fichier EST la licence : il n'a pas sa place sur une cle
                    # USB qui se perd. La page le dit au lieu de le supposer.
                    secret   = $true
                }
            }
        }
    }
    if (-not $out.Count) { Write-Host " aucun"; return @() }
    Write-Host " $($out.Count) fichier(s)"
    return $out
}

# ------------------------------------------------------------------- VPN
#
# Windows tient ses propres connexions VPN dans un annuaire que le module
# VpnClient sait lire, sans droits administrateur : nom, serveur, type de
# tunnel. Aucun secret n'en sort, et c'est voulu — un mot de passe ou une cle
# pre-partagee n'a rien a faire dans un inventaire qui voyage sur une cle USB.
#
# Les clients tiers, eux, ne se lisent pas : chacun a son format. On constate
# la presence de leurs fichiers de configuration, en disant lesquels
# contiennent une cle. Et les VPN par abonnement (Nord, Proton, Mullvad,
# Tailscale) n'ont rien a copier du tout : c'est un compte, pas un fichier.

$TypesTunnel = @{
    'Pptp' = 'PPTP'; 'L2tp' = 'L2TP/IPsec'; 'Sstp' = 'SSTP'
    'Ikev2' = 'IKEv2'; 'Automatic' = 'automatique'
}

function Format-Vpn {
    param($Connexions)
    $out = @()
    foreach ($c in @($Connexions)) {
        if (-not $c) { continue }
        $nom = ''
        $pn = $c.PSObject.Properties['Name']
        if ($pn) { $nom = [string]$pn.Value }
        if ([string]::IsNullOrWhiteSpace($nom)) { continue }

        $serveur = ''
        $ps = $c.PSObject.Properties['ServerAddress']
        if ($ps) { $serveur = ([string]$ps.Value).Trim() }

        $type = ''
        $pt = $c.PSObject.Properties['TunnelType']
        if ($pt -and $pt.Value) {
            $brut = [string]$pt.Value
            $type = if ($TypesTunnel.ContainsKey($brut)) { $TypesTunnel[$brut] } else { $brut }
        }

        $out += [ordered]@{
            nom      = $nom.Trim()
            serveur  = $serveur
            type     = $type
            source   = 'Windows'
            # Le mot de passe et la cle pre-partagee restent sur l'ancienne
            # machine : la connexion se recree a la main, en trois champs.
            quoi     = "Connexion VPN de Windows. A recreer a la main sur la machine neuve : le mot de passe n'est pas relevé."
            secret   = $false
        }
    }
    return $out
}

# Les fichiers de configuration des clients tiers. On ne les lit jamais : un
# .ovpn porte la cle privee en clair, une conf WireGuard aussi.
$ConfigsVpnTierces = @(
    @{ nom = 'OpenVPN'; chemins = @('%USERPROFILE%\OpenVPN\config\*.ovpn', '%PROGRAMFILES%\OpenVPN\config\*.ovpn')
       quoi = "Profil OpenVPN : il contient la cle privee en clair. A traiter comme un mot de passe." }
    @{ nom = 'WireGuard'; chemins = @('%PROGRAMFILES%\WireGuard\Data\Configurations\*')
       quoi = "Tunnel WireGuard. Le fichier est chiffre pour cette machine-ci : il ne se recopie pas, il faut le reexporter depuis l'application avant de formater." }
)

# Ceux-la n'ont aucun fichier a emporter : le compte suffit. Le dire evite de
# chercher une configuration qui n'existe pas.
$VpnParAbonnement = @('nordvpn', 'protonvpn', 'mullvad', 'tailscale', 'expressvpn', 'cyberghost', 'surfshark', 'windscribe')

function Get-VpnAbonnement {
    param([string[]]$ClesInstallees = @())
    $out = @()
    foreach ($cle in @($ClesInstallees)) {
        if ([string]::IsNullOrWhiteSpace($cle)) { continue }
        foreach ($m in $VpnParAbonnement) {
            if ($cle -like "*$m*") {
                $out += [ordered]@{
                    nom = $m; serveur = ''; type = 'abonnement'; source = 'application installee'
                    quoi = "VPN par abonnement : rien a copier, tout est dans le compte. Verifie que tu peux encore t'y connecter."
                    secret = $false
                }
                break
            }
        }
    }
    return $out
}

function Read-Vpn {
    param([string[]]$ClesInstallees = @())
    Write-Host "  VPN..." -NoNewline
    $out = @()
    try {
        $cx = Get-VpnConnection -ErrorAction Stop
        $out += @(Format-Vpn -Connexions $cx)
    } catch { }
    # Les connexions posees pour toute la machine vivent ailleurs.
    try {
        $cx = Get-VpnConnection -AllUserConnection -ErrorAction Stop
        $out += @(Format-Vpn -Connexions $cx)
    } catch { }

    foreach ($regle in $ConfigsVpnTierces) {
        foreach ($modele in @($regle.chemins)) {
            foreach ($r in @(Expand-CheminModele -Modele $modele)) {
                $out += [ordered]@{
                    nom = $regle.nom; serveur = ''; type = 'fichier'
                    source = $r.chemin; modele = $r.modele
                    quoi = $regle.quoi
                    secret = $true
                }
            }
        }
    }
    $out += @(Get-VpnAbonnement -ClesInstallees $ClesInstallees)

    if (-not $out.Count) { Write-Host " aucun"; return @() }
    Write-Host " $($out.Count) connexion(s)"
    return $out
}

# --------------------------------------------------------------- favoris
#
# Les navigateurs Chromium rangent leurs marque-pages dans un fichier
# « Bookmarks » qui est du JSON en clair : on peut donc en donner le nombre,
# ce qui rend la ligne verifiable au lieu de vague. Firefox les met dans
# places.sqlite, verrouille quand le navigateur tourne et illisible sans
# SQLite : la, on se contente du chemin et de la taille. Dire « je ne sais pas
# combien » vaut mieux que d'embarquer une dependance pour le savoir.

function Measure-FavorisChromium {
    param([string]$Json)
    if ([string]::IsNullOrWhiteSpace($Json)) { return $null }
    try { $d = $Json | ConvertFrom-Json } catch { return $null }
    if (-not $d -or -not $d.PSObject.Properties['roots']) { return $null }
    $n = 0
    $pile = New-Object System.Collections.Stack
    foreach ($p in $d.roots.PSObject.Properties) { $pile.Push($p.Value) }
    while ($pile.Count) {
        $noeud = $pile.Pop()
        if ($null -eq $noeud) { continue }
        $type = ''
        if ($noeud.PSObject.Properties['type']) { $type = [string]$noeud.type }
        if ($type -eq 'url') { $n++; continue }
        if ($noeud.PSObject.Properties['children']) {
            foreach ($e in @($noeud.children)) { $pile.Push($e) }
        }
    }
    return $n
}

$NavigateursFavoris = @(
    @{ nom = 'Chrome';   base = 'LOCALAPPDATA'; chemin = 'Google\Chrome\User Data' }
    @{ nom = 'Edge';     base = 'LOCALAPPDATA'; chemin = 'Microsoft\Edge\User Data' }
    @{ nom = 'Brave';    base = 'LOCALAPPDATA'; chemin = 'BraveSoftware\Brave-Browser\User Data' }
    @{ nom = 'Vivaldi';  base = 'LOCALAPPDATA'; chemin = 'Vivaldi\User Data' }
    @{ nom = 'Opera';    base = 'APPDATA';      chemin = 'Opera Software\Opera Stable' }
)

function Read-Favoris {
    Write-Host "  favoris..." -NoNewline
    $out = @()
    foreach ($nav in $NavigateursFavoris) {
        $racine = Join-CheminSur (Get-Item "env:$($nav.base)" -ErrorAction SilentlyContinue).Value $nav.chemin
        if (-not $racine -or -not (Test-Path -LiteralPath $racine)) { continue }
        # Opera range ses marque-pages a la racine ; Chrome les met par profil.
        $candidats = @(Join-Path $racine 'Bookmarks')
        foreach ($d in @(Get-ChildItem -LiteralPath $racine -Directory -Force -ErrorAction SilentlyContinue)) {
            if ($d.Name -ne 'Default' -and $d.Name -notlike 'Profile *') { continue }
            $candidats += (Join-Path $d.FullName 'Bookmarks')
        }
        foreach ($f in $candidats) {
            if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { continue }
            $n = $null
            try { $n = Measure-FavorisChromium -Json (Get-Content -LiteralPath $f -Raw -Encoding UTF8) } catch { }
            $out += [ordered]@{
                navigateur = $nav.nom
                profil     = (Split-Path (Split-Path $f -Parent) -Leaf)
                chemin     = $f
                nombre     = $n
                quoi       = "Marque-pages $($nav.nom). Fichier unique, se recopie tel quel dans le meme profil."
            }
        }
    }
    # Firefox : on constate, on ne compte pas.
    $profils = Join-CheminSur $env:APPDATA 'Mozilla\Firefox\Profiles'
    if ($profils -and (Test-Path -LiteralPath $profils)) {
        foreach ($p in @(Get-ChildItem -LiteralPath $profils -Directory -Force -ErrorAction SilentlyContinue)) {
            $f = Join-Path $p.FullName 'places.sqlite'
            if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { continue }
            $out += [ordered]@{
                navigateur = 'Firefox'
                profil     = $p.Name
                chemin     = $f
                nombre     = $null
                quoi       = "Marque-pages et historique Firefox. Verrouille tant que Firefox tourne, et illisible sans SQLite : le scan constate le fichier sans le compter."
            }
        }
    }
    if (-not $out.Count) { Write-Host " aucun"; return @() }
    Write-Host " $($out.Count) jeu(x) de favoris"
    return $out
}

# --------------------------------------------- machines virtuelles
#
# Une machine virtuelle ne se reinstalle pas : elle se copie, ou elle se
# refait de zero. Et elle pese des dizaines de gigaoctets, ce qui change la
# taille du disque a commander. C'est la seule chose que le scan peut dire
# honnetement : quelles machines existent, ou, et combien elles pesent.
#
# VirtualBox tient un registre XML lisible sans droits particuliers. VMware
# Workstation tient un inventaire texte. Hyper-V repond a Get-VM, mais
# seulement si la fonctionnalite est installee, et le plus souvent en
# administrateur : son absence n'est pas une erreur.

# Split-Path et [System.IO.Path] suivent le separateur de la machine qui lit.
# Sous Linux — ou tournent les tests — « C:\VMs\Debian\Debian.vbox » n'a aucun
# separateur a leurs yeux : Split-Path rend le chemin entier, et
# GetFileNameWithoutExtension aussi. Ces chemins-la viennent de fichiers de
# configuration Windows : ils s'analysent avec la regle de Windows, pas avec
# celle de l'hote.
function Split-CheminWindows {
    param([string]$Chemin)
    $c = ([string]$Chemin).TrimEnd('\', '/')
    if ([string]::IsNullOrWhiteSpace($c)) { return [ordered]@{ parent = ''; feuille = '' } }
    $i = $c.LastIndexOfAny([char[]]@('\', '/'))
    if ($i -lt 0) { return [ordered]@{ parent = ''; feuille = $c } }
    return [ordered]@{ parent = $c.Substring(0, $i); feuille = $c.Substring($i + 1) }
}
function Get-NomSansExtension {
    param([string]$Chemin)
    $f = (Split-CheminWindows -Chemin $Chemin).feuille
    $i = $f.LastIndexOf('.')
    if ($i -le 0) { return $f }
    return $f.Substring(0, $i)
}

function Format-VmVirtualBox {
    param([string]$Xml)
    $out = @()
    if ([string]::IsNullOrWhiteSpace($Xml)) { return $out }
    try { $d = [xml]$Xml } catch { return $out }
    foreach ($m in @($d.SelectNodes('//*[local-name()="MachineEntry"]'))) {
        if (-not $m) { continue }
        $src = [string]$m.src
        if ([string]::IsNullOrWhiteSpace($src)) { continue }
        # Le .vbox vit dans le dossier de la machine : c'est ce dossier qui pese.
        $decoupe = Split-CheminWindows -Chemin $src
        $dossier = $decoupe.parent
        $out += [ordered]@{
            nom          = if ($dossier) { (Split-CheminWindows -Chemin $dossier).feuille } else { $src }
            hyperviseur  = 'VirtualBox'
            chemin       = if ($dossier) { $dossier } else { $src }
            tailleMo     = $null
        }
    }
    return $out
}

function Format-VmVmware {
    param([string]$Inventaire)
    $out = @()
    if ([string]::IsNullOrWhiteSpace($Inventaire)) { return $out }
    foreach ($ligne in ($Inventaire -split "`r?`n")) {
        # vmlist1.config = "C:\VMs\Debian\Debian.vmx"
        if ($ligne -notmatch '^\s*vmlist\d+\.config\s*=\s*"(.+?)"\s*$') { continue }
        $vmx = $Matches[1]
        $dossier = (Split-CheminWindows -Chemin $vmx).parent
        $out += [ordered]@{
            nom         = Get-NomSansExtension -Chemin $vmx
            hyperviseur = 'VMware'
            chemin      = if ($dossier) { $dossier } else { $vmx }
            tailleMo    = $null
        }
    }
    return $out
}

function Format-VmHyperV {
    param($Machines)
    $out = @()
    foreach ($m in @($Machines)) {
        if (-not $m) { continue }
        $nom = ''
        $pn = $m.PSObject.Properties['Name']
        if ($pn) { $nom = [string]$pn.Value }
        if ([string]::IsNullOrWhiteSpace($nom)) { continue }
        $chemin = ''
        $pc = $m.PSObject.Properties['Path']
        if ($pc) { $chemin = [string]$pc.Value }
        $out += [ordered]@{
            nom = $nom.Trim(); hyperviseur = 'Hyper-V'; chemin = $chemin; tailleMo = $null
        }
    }
    return $out
}

function Read-MachinesVirtuelles {
    Write-Host "  machines virtuelles..." -NoNewline
    $out = @()
    $vbox = Join-CheminSur $env:USERPROFILE '.VirtualBox\VirtualBox.xml'
    if ($vbox -and (Test-Path -LiteralPath $vbox -PathType Leaf)) {
        try { $out += @(Format-VmVirtualBox -Xml (Get-Content -LiteralPath $vbox -Raw -Encoding UTF8)) } catch { }
    }
    $vmw = Join-CheminSur $env:APPDATA 'VMware\inventory.vmls'
    if ($vmw -and (Test-Path -LiteralPath $vmw -PathType Leaf)) {
        try { $out += @(Format-VmVmware -Inventaire (Get-Content -LiteralPath $vmw -Raw -Encoding UTF8)) } catch { }
    }
    try { $out += @(Format-VmHyperV -Machines (Get-VM -ErrorAction Stop)) } catch { }

    # La taille est ce qui compte ici : on la mesure apres coup, une seule fois
    # par dossier, parce que c'est l'operation lente de tout le scan.
    foreach ($vm in $out) {
        if ($vm.chemin -and (Test-Path -LiteralPath $vm.chemin)) {
            $vm.tailleMo = Get-TailleDossier -Chemin $vm.chemin
        }
    }
    if (-not $out.Count) { Write-Host " aucune"; return @() }
    Write-Host " $($out.Count) machine(s)"
    return $out
}

# ------------------------------------------------- archives mail locales
#
# Une distinction que personne ne fait spontanement, et qui decide de tout :
# un .pst est une archive qui n'existe nulle part ailleurs — perdu, perdu. Un
# .ost est le cache local d'un compte IMAP ou Exchange : il se reconstruit
# tout seul a la premiere connexion, et le copier ne sert a rien. Ils se
# ressemblent, ils vivent cote a cote, et ils ne valent pas la meme chose.

$DossiersMail = @(
    '%LOCALAPPDATA%\Microsoft\Outlook\*.pst', '%LOCALAPPDATA%\Microsoft\Outlook\*.ost',
    '%USERPROFILE%\Documents\Fichiers Outlook\*.pst',
    '%USERPROFILE%\Documents\Outlook Files\*.pst'
)

function Read-ArchivesMail {
    Write-Host "  archives mail..." -NoNewline
    $out = @()
    foreach ($modele in $DossiersMail) {
        foreach ($r in @(Expand-CheminModele -Modele $modele)) {
            $feuille = (Split-CheminWindows -Chemin $r.chemin).feuille
            $ext = ''
            $pt = $feuille.LastIndexOf('.')
            if ($pt -gt 0) { $ext = $feuille.Substring($pt).ToLowerInvariant() }
            $mo = $null
            try { $mo = [math]::Round((Get-Item -LiteralPath $r.chemin -Force -ErrorAction Stop).Length / 1MB, 1) } catch { }
            $cache = ($ext -eq '.ost')
            $out += [ordered]@{
                nom      = $feuille
                chemin   = $r.chemin
                modele   = $r.modele
                cache    = $cache
                tailleMo = $mo
                quoi     = if ($cache) {
                    "Cache local d'un compte en ligne (.ost). Il se reconstruit tout seul a la premiere connexion : rien a copier."
                } else {
                    "Archive Outlook (.pst) : ces messages n'existent nulle part ailleurs. Perdue, elle ne revient pas."
                }
            }
        }
    }
    if (-not $out.Count) { Write-Host " aucune"; return @() }
    Write-Host " $($out.Count) fichier(s)"
    return $out
}

# ------------------------------------------------------------ BitLocker
#
# Ici le scan s'arrete volontairement avant la fin. Get-BitLockerVolume rend
# aussi le mot de passe de recuperation a 48 chiffres — et ce mot de passe EST
# la securite du disque. L'ecrire dans un inventaire qui voyage sur une cle USB
# annulerait le chiffrement qu'on vient de constater. On releve donc quels
# volumes sont chiffres et quels types de protecteurs existent, jamais leur
# contenu, et la checklist rappelle de noter la cle ailleurs, a la main.
#
# La lecture demande les droits administrateur. Sans eux, on le dit, comme
# pour Secure Boot et le compteur d'heures des disques.

$TypesProtecteur = @{
    'RecoveryPassword' = 'mot de passe de recuperation'
    'Tpm'              = 'TPM'
    'TpmPin'           = 'TPM + code PIN'
    'TpmStartupKey'    = 'TPM + cle de demarrage'
    'ExternalKey'      = 'cle externe (USB)'
    'Password'         = 'mot de passe'
    'RecoveryKey'      = 'fichier de cle de recuperation'
}

function Format-Bitlocker {
    param($Volumes)
    $out = @()
    foreach ($v in @($Volumes)) {
        if (-not $v) { continue }
        $lettre = ''
        $pl = $v.PSObject.Properties['MountPoint']
        if ($pl) { $lettre = [string]$pl.Value }
        if ([string]::IsNullOrWhiteSpace($lettre)) { continue }

        $etat = ''
        $pe = $v.PSObject.Properties['ProtectionStatus']
        if ($pe) { $etat = [string]$pe.Value }

        $types = @()
        $pp = $v.PSObject.Properties['KeyProtector']
        if ($pp) {
            foreach ($k in @($pp.Value)) {
                if (-not $k) { continue }
                $t = ''
                $pt = $k.PSObject.Properties['KeyProtectorType']
                if ($pt) { $t = [string]$pt.Value }
                if ([string]::IsNullOrWhiteSpace($t)) { continue }
                $lisible = if ($TypesProtecteur.ContainsKey($t)) { $TypesProtecteur[$t] } else { $t }
                if ($types -notcontains $lisible) { $types += $lisible }
            }
        }
        $chiffre = ($etat -eq 'On' -or $etat -eq '1')
        $aCle = ($types -contains 'mot de passe de recuperation' -or $types -contains 'fichier de cle de recuperation')
        $out += [ordered]@{
            volume       = $lettre
            chiffre      = $chiffre
            protecteurs  = $types
            cleExiste    = $aCle
            quoi         = if (-not $chiffre) {
                "Volume non chiffre : rien a prevoir."
            } elseif ($aCle) {
                "Volume chiffre, avec une cle de recuperation. Le scan ne la releve pas, et ne la relevera jamais : elle ouvre le disque a qui la lit. Va la chercher dans ton compte Microsoft ou imprime-la, avant de toucher au materiel."
            } else {
                "Volume chiffre, sans cle de recuperation declaree. Un changement de carte mere ou de TPM rendrait le disque illisible : cree une cle de recuperation et note-la ailleurs avant de demonter quoi que ce soit."
            }
        }
    }
    return $out
}

function Read-Bitlocker {
    Write-Host "  BitLocker..." -NoNewline
    $volumes = $null
    try { $volumes = Get-BitLockerVolume -ErrorAction Stop } catch {
        Write-Host " indisponible (droits administrateur requis)" -ForegroundColor Yellow
        return @([ordered]@{
            volume = ''; chiffre = $null; protecteurs = @(); cleExiste = $null
            quoi = "Impossible de savoir si les disques sont chiffres : relance ce script en tant qu'administrateur. Si BitLocker est actif, sa cle de recuperation doit etre notee ailleurs avant de toucher au materiel."
        })
    }
    $out = @(Format-Bitlocker -Volumes $volumes)
    if (-not $out.Count) { Write-Host " aucun volume"; return @() }
    Write-Host " $($out.Count) volume(s)"
    return $out
}

# ------------------------------------------------- la machine elle-meme
#
# Fabricant, modele, numero de serie, portable ou fixe, et combien d'ecrans
# sont branches. Rien de tout ca ne se copie : ce sont des faits sur l'ancien
# PC, qui servent a commander le neuf et a reconnaitre la machine au SAV.
#
# Le numero de serie n'est pas un secret — il est imprime sous la machine —
# mais il ne sert qu'a elle : il part dans l'inventaire, pas dans la
# configuration du PC neuf, ou il designerait la mauvaise machine.

# Win32_SystemEnclosure.ChassisTypes : la liste officielle en compte une
# trentaine. Seule la distinction portable/fixe change ce qu'on conseille.
$ChassisPortables = @(8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32)
$ChassisFixes     = @(3, 4, 5, 6, 7, 13, 15, 16, 17, 23, 24, 28, 29)

function Format-Machine {
    param($Systeme, $Bios, $Chassis, $Ecrans)
    $out = [ordered]@{}

    if ($Systeme) {
        $s = @($Systeme)[0]
        $fab = ''
        $pf = $s.PSObject.Properties['Manufacturer']
        if ($pf) { $fab = ([string]$pf.Value).Trim() }
        $mod = ''
        $pm = $s.PSObject.Properties['Model']
        if ($pm) { $mod = ([string]$pm.Value).Trim() }
        # « System manufacturer / System Product Name » est ce que renvoie une
        # machine assemblee dont personne n'a rempli le SMBIOS : l'afficher
        # ferait croire a un modele.
        if ($fab -and $fab -notmatch '^(System manufacturer|To Be Filled|Default string|O\.E\.M\.)') { $out['fabricant'] = $fab }
        if ($mod -and $mod -notmatch '^(System Product Name|To Be Filled|Default string|O\.E\.M\.)') { $out['modele'] = $mod }
    }

    if ($Bios) {
        $b = @($Bios)[0]
        $sn = ''
        $ps = $b.PSObject.Properties['SerialNumber']
        if ($ps) { $sn = ([string]$ps.Value).Trim() }
        # « To Be Filled By O.E.M. » : l'ancre de fin laissait passer tout ce
        # qui suit le mot-cle, c'est-a-dire le cas le plus courant.
        $bidon = ($sn -match '^(To Be Filled|Default string|None|Not Applicable|Chassis Serial)' -or $sn -match '^0+$')
        if ($sn -and -not $bidon) { $out['serie'] = $sn }
    }

    if ($Chassis) {
        $types = @()
        foreach ($c in @($Chassis)) {
            if (-not $c) { continue }
            $pt = $c.PSObject.Properties['ChassisTypes']
            if ($pt) { foreach ($t in @($pt.Value)) { $types += [int]$t } }
        }
        foreach ($t in $types) {
            if ($ChassisPortables -contains $t) { $out['chassis'] = 'portable'; break }
            if ($ChassisFixes -contains $t)     { $out['chassis'] = 'fixe'; break }
        }
    }

    if ($Ecrans) {
        $noms = @()
        foreach ($e in @($Ecrans)) {
            if (-not $e) { continue }
            # WmiMonitorID rend des tableaux de codes de caracteres, termines
            # par des zeros : « 68,101,108,108,0,0 » veut dire « Dell ».
            $nom = ''
            $pn = $e.PSObject.Properties['UserFriendlyName']
            if ($pn -and $pn.Value) {
                $nom = -join (@($pn.Value) | Where-Object { $_ -gt 0 } | ForEach-Object { [char][int]$_ })
            }
            $nom = $nom.Trim()
            if ($nom) { $noms += $nom }
        }
        if ($noms.Count) {
            $out['ecrans'] = $noms.Count
            $out['modelesEcrans'] = @($noms)
        }
    }
    return $out
}

# Le bloc « machine » porte deja l'OS et le nom du poste. Ce qui vient de
# Format-Machine s'y ajoute sans les ecraser.
function Merge-Machine {
    param($Base, $Ajouts)
    $out = [ordered]@{}
    foreach ($k in @($Base.Keys)) { $out[$k] = $Base[$k] }
    if ($Ajouts) { foreach ($k in @($Ajouts.Keys)) { if (-not $out.Contains($k)) { $out[$k] = $Ajouts[$k] } } }
    return $out
}

function Read-Machine {
    Write-Host "  machine..." -NoNewline
    $out = [ordered]@{}
    try {
        $out = Format-Machine `
            -Systeme (Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue) `
            -Bios    (Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue) `
            -Chassis (Get-CimInstance Win32_SystemEnclosure -ErrorAction SilentlyContinue) `
            -Ecrans  (Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction SilentlyContinue)
    } catch {
        Write-Host " indisponible, ignore" -ForegroundColor Yellow
        return [ordered]@{}
    }
    Write-Host " $(@($out.Keys).Count) information(s)"
    return $out
}

# ------------------------------------------------------------ antivirus
#
# Windows tient la liste des antivirus declares dans un espace de noms a part.
# Defender y figure aussi : c'est celui qu'on ne compte pas, il revient tout
# seul. Un antivirus tiers, lui, est presque toujours un abonnement — donc une
# licence a retrouver avant de formater, pas juste un logiciel a reinstaller.

function Format-Antivirus {
    param($Produits)
    $out = @()
    foreach ($p in @($Produits)) {
        if (-not $p) { continue }
        $nom = ''
        $pn = $p.PSObject.Properties['displayName']
        if ($pn) { $nom = ([string]$pn.Value).Trim() }
        if ([string]::IsNullOrWhiteSpace($nom)) { continue }
        # Defender revient seul apres une reinstallation : rien a prevoir.
        $integre = ($nom -match 'Windows Defender|Microsoft Defender')
        $out += [ordered]@{
            nom     = $nom
            integre = $integre
            quoi    = if ($integre) {
                "Livre avec Windows : il revient tout seul apres la reinstallation."
            } else {
                "Antivirus tiers : presque toujours un abonnement, avec un nombre de postes limite. Retrouve la licence et delie l'ancien poste avant de le demonter."
            }
        }
    }
    return $out
}

function Read-Antivirus {
    Write-Host "  antivirus..." -NoNewline
    try {
        $p = Get-CimInstance -Namespace 'root\SecurityCenter2' -ClassName AntiVirusProduct -ErrorAction Stop
        $out = @(Format-Antivirus -Produits $p)
        if (-not $out.Count) { Write-Host " aucun"; return @() }
        Write-Host " $($out.Count) produit(s)"
        return $out
    } catch {
        Write-Host " indisponible, ignore" -ForegroundColor Yellow
        return @()
    }
}

# --------------------------------------------------- pilotes a retrouver
#
# Ce qu'on NE peut PAS faire : dire « installez le pilote X version Y ». Il
# faudrait une table reliant chaque modele a son pilote, que personne ne tient
# a jour. Ce qu'on PEUT faire : dire quels peripheriques ont un pilote qui ne
# vient PAS de Microsoft. Ceux-la, Windows Update ne les retrouvera pas
# forcement tout seul — c'est exactement la liste a preparer avant de formater.

# Les classes ou un pilote tiers est la norme et ne pose jamais de probleme :
# les lister noierait les trois qui comptent.
$ClassesPilotesBanales = @('Printer', 'Volume', 'DiskDrive', 'CDROM', 'Monitor', 'Keyboard', 'Mouse')

function Format-PilotesTiers {
    param($Pilotes)
    $vus = @{}
    $out = @()
    foreach ($p in @($Pilotes)) {
        if (-not $p) { continue }
        $fournisseur = ''
        $pf = $p.PSObject.Properties['DriverProviderName']
        if ($pf) { $fournisseur = ([string]$pf.Value).Trim() }
        if ([string]::IsNullOrWhiteSpace($fournisseur)) { continue }
        if ($fournisseur -match '^Microsoft') { continue }

        $classe = ''
        $pc = $p.PSObject.Properties['DeviceClass']
        if ($pc) { $classe = ([string]$pc.Value).Trim() }
        if ($ClassesPilotesBanales -contains $classe) { continue }

        $appareil = ''
        $pd = $p.PSObject.Properties['DeviceName']
        if ($pd) { $appareil = ([string]$pd.Value).Trim() }
        if ([string]::IsNullOrWhiteSpace($appareil)) { continue }

        # Une carte mere declare vingt peripheriques du meme fournisseur dans
        # la meme classe : une ligne par couple suffit a savoir quoi chercher.
        $cle = ($fournisseur + '|' + $classe).ToLowerInvariant()
        if ($vus.ContainsKey($cle)) {
            if ($vus[$cle].appareils.Count -lt 3 -and $vus[$cle].appareils -notcontains $appareil) {
                $vus[$cle].appareils += $appareil
            }
            continue
        }
        $entree = [ordered]@{
            fournisseur = $fournisseur
            classe      = if ($classe) { $classe } else { 'Autre' }
            appareils   = @($appareil)
        }
        $vus[$cle] = $entree
        $out += $entree
    }
    return $out
}

function Read-PilotesTiers {
    Write-Host "  pilotes tiers..." -NoNewline
    try {
        $p = Get-CimInstance Win32_PnPSignedDriver -ErrorAction Stop
        $out = @(Format-PilotesTiers -Pilotes $p)
        if (-not $out.Count) { Write-Host " aucun"; return @() }
        Write-Host " $($out.Count) fournisseur(s)"
        return $out
    } catch {
        Write-Host " indisponible, ignore" -ForegroundColor Yellow
        return @()
    }
}

# ------------------------------------------------------ compte Microsoft
#
# Sur quel compte ouvrir la session du PC neuf. Windows le range dans un cache
# d'identite, sous le SID de l'utilisateur. Ce n'est qu'une adresse de
# courriel — la meme qui s'affiche dans les Parametres — et elle evite de
# creer un compte local par defaut puis de tout refaire.

function Read-CompteMicrosoft {
    Write-Host "  compte Microsoft..." -NoNewline
    $racine = 'HKLM:\SOFTWARE\Microsoft\IdentityStore\Cache'
    if (-not (Test-CleRegistre $racine)) { Write-Host " aucun"; return '' }
    foreach ($sid in @(Get-ChildItem -LiteralPath $racine -ErrorAction SilentlyContinue)) {
        $cache = Join-Path $sid.PSPath 'IdentityCache'
        if (-not (Test-Path -LiteralPath $cache)) { continue }
        foreach ($e in @(Get-ChildItem -LiteralPath $cache -ErrorAction SilentlyContinue)) {
            $v = Get-ItemProperty -LiteralPath $e.PSPath -ErrorAction SilentlyContinue
            if (-not $v) { continue }
            $p = $v.PSObject.Properties['UserName']
            if ($p -and $p.Value -and ([string]$p.Value) -like '*@*') {
                Write-Host " trouve"
                return ([string]$p.Value).Trim()
            }
        }
    }
    Write-Host " aucun"
    return ''
}

# ----------------------------------------------------------- imprimantes
#
# Une imprimante reseau se retrouve en deux clics quand on connait son nom et
# son adresse ; sans eux, on cherche un modele dans une liste de trois cents.
# Les imprimantes virtuelles — PDF, XPS, OneNote, fax — reviennent avec
# Windows : les lister ferait croire qu'il y a six choses a reinstaller.

$ImprimantesVirtuelles = @('Microsoft Print to PDF', 'Microsoft XPS Document Writer',
    'OneNote', 'Fax', 'Envoyer A OneNote', 'Send To OneNote', 'Adobe PDF')

function Format-Imprimantes {
    param($Imprimantes)
    $out = @()
    foreach ($i in @($Imprimantes)) {
        if (-not $i) { continue }
        $nom = ''
        $pn = $i.PSObject.Properties['Name']
        if ($pn) { $nom = ([string]$pn.Value).Trim() }
        if ([string]::IsNullOrWhiteSpace($nom)) { continue }
        $virtuelle = $false
        foreach ($v in $ImprimantesVirtuelles) { if ($nom -like "*$v*") { $virtuelle = $true; break } }
        if ($virtuelle) { continue }

        $pilote = ''
        $pd = $i.PSObject.Properties['DriverName']
        if ($pd) { $pilote = ([string]$pd.Value).Trim() }
        $port = ''
        $pp = $i.PSObject.Properties['PortName']
        if ($pp) { $port = ([string]$pp.Value).Trim() }
        $reseau = $false
        $pr = $i.PSObject.Properties['Network']
        if ($pr -and $pr.Value) { $reseau = [bool]$pr.Value }
        # Un port « IP_192.168.1.50 » ou « WSD-... » designe une imprimante
        # joignable par le reseau, meme quand Network vaut faux.
        if ($port -match '^(IP_|WSD|\d{1,3}(\.\d{1,3}){3})') { $reseau = $true }

        $out += [ordered]@{
            nom    = $nom
            pilote = $pilote
            port   = $port
            reseau = $reseau
            quoi   = if ($reseau) {
                "Imprimante reseau : elle se rajoute par son adresse, sans toucher au materiel."
            } else {
                "Imprimante locale : garde le nom du pilote, c'est lui qu'il faudra retrouver chez le constructeur."
            }
        }
    }
    return $out
}

function Read-Imprimantes {
    Write-Host "  imprimantes..." -NoNewline
    try {
        $out = @(Format-Imprimantes -Imprimantes (Get-CimInstance Win32_Printer -ErrorAction Stop))
        if (-not $out.Count) { Write-Host " aucune"; return @() }
        Write-Host " $($out.Count) imprimante(s)"
        return $out
    } catch {
        Write-Host " indisponible, ignore" -ForegroundColor Yellow
        return @()
    }
}

# ---------------------------------------------------------------- Wi-Fi
#
# Meme regle que BitLocker, et pour la meme raison. « netsh wlan export
# profile key=clear » ecrit les cles Wi-Fi en clair dans des fichiers XML —
# et cet inventaire voyage sur une cle USB. On releve donc les NOMS des
# reseaux, qui ne sont pas des secrets (ils sont diffuses a la ronde), et on
# dit ou l'utilisateur va chercher les mots de passe lui-meme.
#
# Le nom seul est deja la moitie du travail : c'est la liste de ce qu'il
# faudra reconnecter, et celle qu'on oublie — le reseau du bureau, celui des
# parents, le partage de connexion du telephone.

function Format-ProfilsWifi {
    param([string[]]$Lignes)
    $out = @()
    foreach ($l in @($Lignes)) {
        if ([string]::IsNullOrWhiteSpace($l)) { continue }
        # « Profil Tous les utilisateurs : Livebox-1234 » en francais,
        # « All User Profile : Livebox-1234 » en anglais.
        if ($l -notmatch '^\s*(?:Profil|All User|Tous les utilisateurs).*?:\s*(.+?)\s*$') { continue }
        $nom = $matches[1].Trim()
        if ([string]::IsNullOrWhiteSpace($nom)) { continue }
        if ($out | Where-Object { $_.nom -eq $nom }) { continue }
        $out += [ordered]@{
            nom  = $nom
            quoi = "Reseau enregistre sur l'ancien PC. Le scan releve le nom, jamais la cle : « netsh wlan export profile key=clear » l'ecrirait en clair, et cet inventaire voyage sur une cle USB."
        }
    }
    return $out
}

function Read-Wifi {
    Write-Host "  reseaux Wi-Fi..." -NoNewline
    try {
        $lignes = @(& netsh wlan show profiles 2>$null)
        $out = @(Format-ProfilsWifi -Lignes $lignes)
        if (-not $out.Count) { Write-Host " aucun"; return @() }
        Write-Host " $($out.Count) reseau(x)"
        return $out
    } catch {
        Write-Host " indisponible, ignore" -ForegroundColor Yellow
        return @()
    }
}

# --------------------------------------------- identifiants enregistres
#
# Le gestionnaire d'identification de Windows garde les mots de passe des
# partages reseau, des sessions Bureau a distance et de quelques applications.
# « cmdkey /list » donne les CIBLES, jamais les secrets — et c'est tout ce
# qu'on veut : la liste de ce qu'il faudra ressaisir, pas de quoi le faire a
# la place de quelqu'un.

function Format-Identifiants {
    param([string[]]$Lignes)
    $out = @()
    foreach ($l in @($Lignes)) {
        if ([string]::IsNullOrWhiteSpace($l)) { continue }
        if ($l -notmatch '^\s*(?:Cible|Target)\s*:\s*(.+?)\s*$') { continue }
        $cible = $matches[1].Trim()
        if ([string]::IsNullOrWhiteSpace($cible)) { continue }
        # Les entrees posees par Windows lui-meme reviennent toutes seules.
        if ($cible -like 'virtualapp/*' -or $cible -like '*SSO_POP_Device*' -or
            $cible -like 'WindowsLive:*') { continue }
        if ($out | Where-Object { $_.cible -eq $cible }) { continue }
        $out += [ordered]@{
            cible = $cible
            quoi  = "Identifiant enregistre pour cette cible. Le scan releve le nom, jamais le mot de passe : il faudra le ressaisir une fois."
        }
    }
    return $out
}

function Read-Identifiants {
    Write-Host "  identifiants enregistres..." -NoNewline
    try {
        $out = @(Format-Identifiants -Lignes @(& cmdkey /list 2>$null))
        if (-not $out.Count) { Write-Host " aucun"; return @() }
        Write-Host " $($out.Count) cible(s)"
        return $out
    } catch {
        Write-Host " indisponible, ignore" -ForegroundColor Yellow
        return @()
    }
}

# --------------------------------------------------------------- polices
#
# Une police manquante ne fait pas planter : elle remplace silencieusement le
# texte par une autre, et le document ne ressemble plus a rien. Windows garde
# les siennes au registre ; celles installees pour un seul utilisateur vivent
# ailleurs et sont precisement celles qu'on a payees ou telechargees.
#
# On ne copie pas les polices livrees avec Windows : elles reviennent seules,
# et les lister noierait les dix qui comptent.

$ClesPolices = @(
    @{ cle = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'; portee = 'machine' }
    @{ cle = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'; portee = 'utilisateur' }
)

function Format-Polices {
    param($Entrees, [string]$Portee = 'machine', [string[]]$Livrees = @())
    $out = @()
    if (-not $Entrees) { return $out }
    foreach ($p in @($Entrees.PSObject.Properties)) {
        if ($p.Name -like 'PS*') { continue }
        $nom = ($p.Name -replace '\s*\(TrueType\)$', '' -replace '\s*\(OpenType\)$', '').Trim()
        if ([string]::IsNullOrWhiteSpace($nom)) { continue }
        $fichier = [string]$p.Value
        if ($Livrees -contains $nom) { continue }
        $out += [ordered]@{
            nom     = $nom
            fichier = $fichier
            portee  = $Portee
            quoi    = if ($Portee -eq 'utilisateur') {
                "Police installee pour toi seul : celle-la ne revient pas avec Windows."
            } else {
                "Police ajoutee sur cette machine. Windows ne la remettra pas tout seul."
            }
        }
    }
    return $out
}

function Read-Polices {
    Write-Host "  polices..." -NoNewline
    # La liste des polices d'origine se lit sur la machine meme : celles dont
    # le fichier vit dans C:\Windows\Fonts et qui sont dans la cle machine
    # sont, a peu de chose pres, celles livrees avec le systeme. Plutot que de
    # tenir une liste figee qui vieillirait mal, on garde uniquement les
    # polices dont le fichier porte un chemin complet, ou celles de la cle
    # utilisateur : ce sont les ajouts.
    $out = @()
    foreach ($regle in $ClesPolices) {
        if (-not (Test-CleRegistre $regle.cle)) { continue }
        $e = Get-ItemProperty -LiteralPath $regle.cle -ErrorAction SilentlyContinue
        foreach ($police in @(Format-Polices -Entrees $e -Portee $regle.portee)) {
            # Un nom de fichier nu (« arial.ttf ») designe C:\Windows\Fonts,
            # donc une police du systeme. Un chemin complet designe un ajout.
            if ($regle.portee -eq 'machine' -and $police.fichier -notmatch '[\\/]') { continue }
            $out += $police
        }
    }
    if (-not $out.Count) { Write-Host " aucune ajoutee"; return @() }
    Write-Host " $($out.Count) police(s) ajoutee(s)"
    return $out
}

# ------------------------------------------------------- lecteurs reseau
#
# Un lecteur reseau est une lettre qui pointe vers un partage. La lettre se
# recree en dix secondes quand on connait le chemin ; sans lui, on cherche le
# nom du NAS dans sa memoire.

function Format-LecteursReseau {
    param($Lecteurs)
    $out = @()
    foreach ($l in @($Lecteurs)) {
        if (-not $l) { continue }
        $lettre = ''
        $pl = $l.PSObject.Properties['LocalPath']
        if ($pl) { $lettre = ([string]$pl.Value).Trim() }
        $cible = ''
        $pr = $l.PSObject.Properties['RemotePath']
        if ($pr) { $cible = ([string]$pr.Value).Trim() }
        if ([string]::IsNullOrWhiteSpace($cible)) { continue }
        $out += [ordered]@{
            lettre = $lettre
            cible  = $cible
            quoi   = "Lecteur reseau. Se recree par son chemin ; le mot de passe du partage, lui, se ressaisit."
        }
    }
    return $out
}

function Read-LecteursReseau {
    Write-Host "  lecteurs reseau..." -NoNewline
    $out = @()
    try { $out += @(Format-LecteursReseau -Lecteurs (Get-SmbMapping -ErrorAction Stop)) } catch { }
    # Les lecteurs memorises mais non connectes n'apparaissent pas dans
    # Get-SmbMapping : ils vivent au registre, et ce sont souvent ceux qu'on
    # oublie precisement parce qu'ils ne sont pas montes aujourd'hui.
    if (-not $out.Count -and (Test-CleRegistre 'HKCU:\Network')) {
        foreach ($d in @(Get-ChildItem -LiteralPath 'HKCU:\Network' -ErrorAction SilentlyContinue)) {
            $v = Get-ItemProperty -LiteralPath $d.PSPath -ErrorAction SilentlyContinue
            if (-not $v) { continue }
            $p = $v.PSObject.Properties['RemotePath']
            if (-not $p -or [string]::IsNullOrWhiteSpace([string]$p.Value)) { continue }
            $out += [ordered]@{
                lettre = ($d.PSChildName + ':')
                cible  = ([string]$p.Value).Trim()
                quoi   = "Lecteur reseau memorise, pas forcement connecte en ce moment."
            }
        }
    }
    if (-not $out.Count) { Write-Host " aucun"; return @() }
    Write-Host " $($out.Count) lecteur(s)"
    return $out
}

# ----------------------------------------------------- lancement au demarrage
#
# Ce qui se lance tout seul a l'ouverture de session. La liste sert a deux
# choses opposees et aussi utiles : remettre ce qu'on veut retrouver, et NE
# PAS remettre ce qui trainait la depuis trois ans.

function Format-Demarrage {
    param($Entrees)
    $out = @()
    foreach ($e in @($Entrees)) {
        if (-not $e) { continue }
        $nom = ''
        $pn = $e.PSObject.Properties['Name']
        if ($pn) { $nom = ([string]$pn.Value).Trim() }
        if ([string]::IsNullOrWhiteSpace($nom)) { continue }
        $cmd = ''
        $pc = $e.PSObject.Properties['Command']
        if ($pc) { $cmd = ([string]$pc.Value).Trim() }
        $ou = ''
        $pl = $e.PSObject.Properties['Location']
        if ($pl) { $ou = ([string]$pl.Value).Trim() }
        $out += [ordered]@{
            nom      = $nom
            commande = $cmd
            ou       = $ou
            quoi     = "Se lance tout seul a l'ouverture de session. A remettre, ou a ne pas remettre : c'est le moment de trancher."
        }
    }
    return $out
}

function Read-Demarrage {
    Write-Host "  lancement au demarrage..." -NoNewline
    try {
        $out = @(Format-Demarrage -Entrees (Get-CimInstance Win32_StartupCommand -ErrorAction Stop))
        if (-not $out.Count) { Write-Host " aucun"; return @() }
        Write-Host " $($out.Count) programme(s)"
        return $out
    } catch {
        Write-Host " indisponible, ignore" -ForegroundColor Yellow
        return @()
    }
}

# -------------------------------------------------------- taches planifiees
#
# Windows en pose plusieurs centaines pour son propre compte. Les lister
# toutes rendrait la liste illisible et inutile : on ne garde que celles
# rangees a la racine, la ou atterrit ce qu'on cree soi-meme, et on ecarte
# celles dont l'auteur est Microsoft.

function Format-TachesPlanifiees {
    param($Taches)
    $out = @()
    foreach ($t in @($Taches)) {
        if (-not $t) { continue }
        $chemin = ''
        $pc = $t.PSObject.Properties['TaskPath']
        if ($pc) { $chemin = ([string]$pc.Value) }
        # Tout ce qui est range dans un sous-dossier vient d'un logiciel ou de
        # Windows ; ce qu'on cree a la main atterrit a la racine.
        if ($chemin -and $chemin.Trim('\') -ne '') { continue }
        $nom = ''
        $pn = $t.PSObject.Properties['TaskName']
        if ($pn) { $nom = ([string]$pn.Value).Trim() }
        if ([string]::IsNullOrWhiteSpace($nom)) { continue }
        $auteur = ''
        $pa = $t.PSObject.Properties['Author']
        if ($pa) { $auteur = ([string]$pa.Value).Trim() }
        if ($auteur -match '^Microsoft') { continue }
        $etat = ''
        $pe = $t.PSObject.Properties['State']
        if ($pe) { $etat = ([string]$pe.Value).Trim() }
        $out += [ordered]@{
            nom    = $nom
            auteur = $auteur
            etat   = $etat
            quoi   = "Tache planifiee creee sur cette machine. Elle ne suit pas la migration : a recreer si elle sert encore."
        }
    }
    return $out
}

function Read-TachesPlanifiees {
    Write-Host "  taches planifiees..." -NoNewline
    try {
        $out = @(Format-TachesPlanifiees -Taches (Get-ScheduledTask -ErrorAction Stop))
        if (-not $out.Count) { Write-Host " aucune a soi"; return @() }
        Write-Host " $($out.Count) tache(s)"
        return $out
    } catch {
        Write-Host " indisponible, ignore" -ForegroundColor Yellow
        return @()
    }
}

# -------------------------------------------------------- regles de pare-feu
#
# Celles qu'on a ajoutees soi-meme, et elles seules. Windows et les
# installateurs en posent des centaines, toutes rangees dans un groupe : les
# regles sans groupe sont celles qu'un humain a creees, souvent pour ouvrir un
# port a un jeu ou a un serveur local.
#
# On les liste pour les re-decider, pas pour les rejouer : recopier des
# ouvertures de pare-feu d'une machine a l'autre sans les relire est
# exactement la mauvaise facon de s'en servir, et la ligne le dit.

function Format-ReglesPareFeu {
    param($Regles)
    $out = @()
    foreach ($r in @($Regles)) {
        if (-not $r) { continue }
        $groupe = ''
        $pg = $r.PSObject.Properties['Group']
        if ($pg -and $pg.Value) { $groupe = ([string]$pg.Value).Trim() }
        if ($groupe) { continue }
        $actif = $true
        $pe = $r.PSObject.Properties['Enabled']
        if ($pe -and $null -ne $pe.Value) { $actif = ([string]$pe.Value -eq 'True' -or [string]$pe.Value -eq '1') }
        if (-not $actif) { continue }
        $action = ''
        $pa = $r.PSObject.Properties['Action']
        if ($pa) { $action = ([string]$pa.Value).Trim() }
        $sens = ''
        $pd = $r.PSObject.Properties['Direction']
        if ($pd) { $sens = ([string]$pd.Value).Trim() }
        # Une regle sortante qui autorise ne change rien : Windows autorise
        # deja tout ce qui sort. Seules les entrantes ouvertes comptent.
        if ($sens -ne 'Inbound' -or $action -ne 'Allow') { continue }
        $nom = ''
        $pn = $r.PSObject.Properties['DisplayName']
        if ($pn) { $nom = ([string]$pn.Value).Trim() }
        if ([string]::IsNullOrWhiteSpace($nom)) { continue }
        $out += [ordered]@{
            nom  = $nom
            sens = $sens
            quoi = "Ouverture entrante ajoutee a la main sur l'ancien PC. A relire avant de la refaire : une ouverture qu'on ne sait plus expliquer ne se recopie pas."
        }
    }
    return $out
}

function Read-PareFeu {
    Write-Host "  regles de pare-feu..." -NoNewline
    try {
        $out = @(Format-ReglesPareFeu -Regles (Get-NetFirewallRule -ErrorAction Stop))
        if (-not $out.Count) { Write-Host " aucune a soi"; return @() }
        Write-Host " $($out.Count) regle(s)"
        return $out
    } catch {
        Write-Host " indisponible, ignore" -ForegroundColor Yellow
        return @()
    }
}

# ------------------------------------------------ associations de fichiers
#
# « Ouvrir avec » : quel programme ouvre un .pdf, un .zip, un .md. Windows
# range le choix de l'utilisateur sous FileExts, signe par un condense lie au
# compte et a la machine — ce qui veut dire qu'il ne se rejoue PAS d'une
# machine a l'autre, meme a la main sur le registre. La liste sert donc a
# refaire les choix en connaissance de cause, pas a les restaurer, et la
# ligne ne promet rien d'autre.

# Les extensions dont l'association ne surprend personne quand elle revient
# au defaut : les lister ferait une liste de cent lignes ou trois comptent.
$ExtensionsBanales = @('.txt', '.log', '.ini', '.url', '.lnk', '.exe', '.dll', '.sys', '.tmp')

function Format-Associations {
    param($Choix)
    $out = @()
    foreach ($c in @($Choix)) {
        if (-not $c) { continue }
        $ext = ''
        $pe = $c.PSObject.Properties['extension']
        if ($pe) { $ext = ([string]$pe.Value).Trim().ToLowerInvariant() }
        if ([string]::IsNullOrWhiteSpace($ext) -or $ext -notlike '.*') { continue }
        if ($ExtensionsBanales -contains $ext) { continue }
        $prog = ''
        $pp = $c.PSObject.Properties['progId']
        if ($pp) { $prog = ([string]$pp.Value).Trim() }
        if ([string]::IsNullOrWhiteSpace($prog)) { continue }
        # Les identifiants poses par Windows lui-meme reviennent seuls.
        if ($prog -like 'AppX*' -or $prog -like 'Applications\\*') { continue }
        $out += [ordered]@{
            extension = $ext
            programme = $prog
            quoi      = "Ouvert par ce programme sur l'ancien PC. Windows signe ce choix pour cette machine-ci : il ne se restaure pas, il se refait une fois le logiciel reinstalle."
        }
    }
    return $out
}

function Read-Associations {
    Write-Host "  associations de fichiers..." -NoNewline
    $racine = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts'
    if (-not (Test-CleRegistre $racine)) { Write-Host " aucune"; return @() }
    $choix = @()
    foreach ($ext in @(Get-ChildItem -LiteralPath $racine -ErrorAction SilentlyContinue)) {
        $uc = Join-Path $ext.PSPath 'UserChoice'
        if (-not (Test-Path -LiteralPath $uc)) { continue }
        $v = Get-ItemProperty -LiteralPath $uc -ErrorAction SilentlyContinue
        if (-not $v) { continue }
        $p = $v.PSObject.Properties['ProgId']
        if (-not $p -or [string]::IsNullOrWhiteSpace([string]$p.Value)) { continue }
        $o = New-Object PSObject
        $o | Add-Member -NotePropertyName 'extension' -NotePropertyValue $ext.PSChildName
        $o | Add-Member -NotePropertyName 'progId' -NotePropertyValue ([string]$p.Value)
        $choix += $o
    }
    $out = @(Format-Associations -Choix $choix)
    if (-not $out.Count) { Write-Host " aucune a soi"; return @() }
    Write-Host " $($out.Count) association(s)"
    return $out
}

# ---------------------------------------------------------------- pilotes
#
# Ce qu'on peut dire honnetement des pilotes, et ce qu'on ne peut pas.
#
# On NE PEUT PAS dire « installez le pilote X version Y » : il faudrait une
# table reliant chaque modele de materiel a son pilote, que personne ne tient
# a jour, et on servirait des liens faux qui ont l'air vrais.
#
# On PEUT dire quels peripheriques Windows signale comme mal installes. Ce
# n'est pas une deduction, c'est ce que le gestionnaire de peripheriques
# affiche avec un point d'exclamation. C'est exactement « ce qui manque ».

# Les codes que Windows attribue a un peripherique en defaut. Seuls ceux qui
# designent un probleme de pilote nous interessent : un peripherique
# simplement desactive par l'utilisateur n'a rien a reparer.
$CodesPilote = @{
    1  = 'mal configure'
    10 = 'ne demarre pas'
    18 = 'pilote a reinstaller'
    19 = 'configuration abimee'
    28 = 'aucun pilote installe'
    31 = 'pilote indisponible'
    37 = 'le pilote refuse de demarrer'
    39 = 'pilote absent ou abime'
    43 = 'arrete par Windows'
}

function Format-Pilotes {
    param($Peripheriques)
    $manquants = @()
    foreach ($p in @($Peripheriques)) {
        if (-not $p) { continue }
        if (-not $p.PSObject.Properties['ConfigManagerErrorCode']) { continue }
        $code = $p.ConfigManagerErrorCode
        if (-not $CodesPilote.ContainsKey([int]$code)) { continue }
        $nom = if ($p.PSObject.Properties['Name'] -and $p.Name) { $p.Name } else { 'Peripherique inconnu' }
        $manquants += [ordered]@{
            nom      = [string]$nom
            classe   = if ($p.PSObject.Properties['PNPClass'] -and $p.PNPClass) { [string]$p.PNPClass } else { '' }
            probleme = $CodesPilote[[int]$code]
            code     = [int]$code
        }
    }
    return $manquants
}

function Read-PilotesManquants {
    Write-Host "  peripheriques sans pilote..." -NoNewline
    try {
        $tout = Get-CimInstance Win32_PnPEntity -ErrorAction Stop
        $r = Format-Pilotes -Peripheriques $tout
        if (@($r).Count) {
            Write-Host " $(@($r).Count) a regler" -ForegroundColor Yellow
        } else {
            Write-Host " aucun"
        }
        return $r
    } catch {
        Write-Host " indisponible, ignore" -ForegroundColor Yellow
        return @()
    }
}
