<#
.SYNOPSIS
    Logique de detection partagee par les scripts du projet.

.DESCRIPTION
    Le projet ne repond qu'a deux questions : quels logiciels sont installes,
    et quels pilotes manquent ou sont a verifier. scan-pc.ps1 fige le PC
    source, puis constate sur la cible ce qui est arrive — c'est le meme
    script des deux cotes, avec -Role.

    Ce fichier porte la detection une seule fois. Un defaut constate sur une
    machine se corrige ici et disparait des deux cotes, au lieu d'etre a
    reparer deux fois dans deux copies qui auront diverge.

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
#
# Cette table a compte jusqu'a trente-deux familles. Le projet ne promet plus
# que deux choses : les logiciels installes, et les pilotes. Ce qui a ete
# retire — reglages, favoris, Wi-Fi, polices, taches, VPN, machines
# virtuelles, gros dossiers — vit dans l'historique git et n'a pas a revenir
# sans une raison nommee. Voir la section « hors perimetre » de COUVERTURE.md.
$CouverturesScan = [ordered]@{
    apps         = 'Read-Registre, Read-Winget, Read-Store'
    jeux         = 'Read-Steam, Read-Epic, Read-GOG, Read-Xbox, Read-Ubisoft, Read-Ea'
    materiel     = 'Read-Materiel'
    machine      = 'Read-Machine'
    pilotesTiers = 'Read-PilotesTiers'
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


# Ecrire un fichier texte en UTF-8 SANS marqueur d'octets.
#
# Set-Content -Encoding UTF8 en pose un sous Windows PowerShell 5.1. La page le
# tolere — le navigateur le retire en decodant — mais rien d'autre : un vrai
# inventaire produit sur une machine a fait echouer un simple ConvertFrom-Json
# hors PowerShell, et l'erreur ne parle que du marqueur, pas de la cause.
# Un fichier d'echange doit pouvoir etre relu par autre chose que nous.
# [System.IO.Path]::GetFullPath resout un chemin relatif contre
# Environment.CurrentDirectory, qui ne suit PAS Set-Location : en PowerShell,
# se deplacer avec « cd » ne le change pas. Quelqu'un qui fait « cd D:\cle »
# puis lance le script voyait donc son fichier ecrit la ou PowerShell avait
# demarre — souvent C:\Windows\System32 — sans que rien ne le dise. Avec un
# nom fixe le defaut passait inapercu ; avec des instantanes dates il fait
# perdre le fichier qu'on vient de produire.
function Resolve-CheminSortie {
    param([string]$Chemin)
    if ([string]::IsNullOrWhiteSpace($Chemin)) { return $Chemin }
    if ([System.IO.Path]::IsPathRooted($Chemin)) {
        return [System.IO.Path]::GetFullPath($Chemin)
    }
    # ProviderPath et non Path : sur un lecteur reseau monte en PSDrive, Path
    # rend « X:\... » que .NET ne connait pas.
    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).ProviderPath $Chemin))
}

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

# ---------------------------------------------------------------- materiel
#
# Le bloc « Ma configuration » de la page attendait une saisie a la main. Or
# Windows connait deja tout ca. On le lui demande.
#
# La lecture (CIM) et la mise en forme sont separees : la lecture ne tourne que
# sous Windows, la mise en forme se teste partout. C'est elle qui decide de ce
# qui s'affiche, donc c'est elle qu'il faut pouvoir verifier.

function Format-Materiel {
    param($CarteMere, $Processeur, $Cartes, $Barrettes, $Disques,
          $Reseau, $Audio, $Bios)

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

    # ---- les trois qui servent a retrouver un pilote ----
    #
    # La carte reseau d'abord, parce que c'est le pilote dont depend la
    # recherche de tous les autres : sans reseau sur une machine fraiche, on
    # ne va rien telecharger. Ethernet et Wi-Fi separement — un fixe n'a
    # souvent que le premier, et on ne cherche pas le meme pilote.
    if ($Reseau) {
        # PhysicalAdapter ecarte les pseudo-cartes ; le filtre par nom ecarte
        # ce qu'une machine de developpement empile : Hyper-V, VirtualBox,
        # VMware, les TAP de VPN, le Bluetooth qui se declare en reseau.
        $vraies = @($Reseau | Where-Object {
            $_.Name -and
            ($_.PSObject.Properties['PhysicalAdapter'] -eq $null -or $_.PhysicalAdapter) -and
            $_.Name -notmatch 'Virtual|Hyper-V|VMware|VirtualBox|TAP-|Loopback|Bluetooth|WAN Miniport|Microsoft Kernel'
        })
        $wifi = @($vraies | Where-Object { $_.Name -match 'Wi-?Fi|Wireless|802\.11|WLAN' })
        $eth  = @($vraies | Where-Object { $_.Name -notmatch 'Wi-?Fi|Wireless|802\.11|WLAN' })
        if ($eth.Count)  { $config['eth']  = ($eth[0].Name).Trim() }
        if ($wifi.Count) { $config['wifi'] = ($wifi[0].Name).Trim() }
    }

    if ($Audio) {
        # La sortie audio d'une carte graphique passe par HDMI et arrive avec
        # le pilote de la carte : la nommer enverrait chercher un pilote qu'on
        # a deja. C'est la puce de la carte mere qui nous interesse.
        $puces = @($Audio | Where-Object {
            $_.Name -and $_.Name -notmatch 'NVIDIA|AMD High Definition Audio|Radeon|Intel\(R\) Display Audio'
        })
        if ($puces.Count) { $config['audio'] = ($puces[0].Name).Trim() }
    }

    if ($Bios) {
        $b = @($Bios)[0]
        $version = ''
        if ($b.PSObject.Properties['SMBIOSBIOSVersion'] -and $b.SMBIOSBIOSVersion) {
            $version = ([string]$b.SMBIOSBIOSVersion).Trim()
        }
        if ($version) {
            # La date compte autant que le numero : « 1402 » ne dit pas s'il
            # date d'un mois ou de trois ans, et c'est la question qu'on se
            # pose devant la page du constructeur.
            # Get-CimInstance rend deja un DateTime ; les formes anciennes
            # rendent la chaine CIM brute « 20250311000000.000000+000 », que
            # [datetime] refuse. On accepte les deux plutot que de perdre la
            # date sur une machine qui repond autrement que prevu.
            $date = ''
            if ($b.PSObject.Properties['ReleaseDate'] -and $b.ReleaseDate) {
                $brut = $b.ReleaseDate
                if ($brut -is [datetime]) {
                    $date = $brut.ToString('yyyy-MM-dd')
                } elseif (([string]$brut) -match '^(\d{4})(\d{2})(\d{2})') {
                    $date = "$($Matches[1])-$($Matches[2])-$($Matches[3])"
                }
            }
            $config['bios'] = if ($date) { "$version ($date)" } else { $version }
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
            -Disques    (Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue) `
            -Reseau     (Get-CimInstance Win32_NetworkAdapter -ErrorAction SilentlyContinue) `
            -Audio      (Get-CimInstance Win32_SoundDevice -ErrorAction SilentlyContinue) `
            -Bios       (Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue)
    } catch {
        Write-Host " indisponible, ignore" -ForegroundColor Yellow
        return [ordered]@{}
    }
    Write-Host " $(@($config.Keys).Count) composant(s)"
    return $config
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
