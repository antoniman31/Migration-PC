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

function Test-Exclu {
    param([string]$Nom)
    if ($ToutInclure) { return $false }
    if ([string]::IsNullOrWhiteSpace($Nom)) { return $true }
    foreach ($mot in $MotsExclus) {
        if ($Nom -like "*$mot*") { return $true }
    }
    return $false
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
        if ([string]::IsNullOrWhiteSpace($exist.editeur) -and $Editeur) { $exist.editeur = $Editeur }
        if ([string]::IsNullOrWhiteSpace($exist.version) -and $Version) { $exist.version = $Version }
        if ($null -eq $exist.tailleGo -and $null -ne $TailleGo) { $exist.tailleGo = $TailleGo }
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
        cat      = $cat
        priorite = Get-Priorite -Categorie $cat
        duree    = Get-Duree -Nom $Nom -Categorie $cat
        tailleGo = $TailleGo
    }
}

# --- source 1 : winget -------------------------------------------------
function Read-Winget {
    Write-Host "  winget..." -NoNewline
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host " absent, ignore" -ForegroundColor Yellow
        return 0
    }
    $n = 0
    try {
        # --accept-source-agreements evite l'invite au premier lancement.
        $lignes = & winget list --accept-source-agreements 2>$null | Out-String
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
            # Une entree sans identifiant exploitable n'apporte rien de plus que le registre.
            $idValide = ($id -match '^[A-Za-z0-9][A-Za-z0-9._-]*\.[A-Za-z0-9._-]+$')
            Add-App -Nom $nom -Editeur '' -Version $ver -Source 'winget' -Winget $(if ($idValide) { $id } else { '' })
            $n++
        }
    } catch {
        Write-Host " erreur ignoree : $($_.Exception.Message)" -ForegroundColor Yellow
        return $n
    }
    Write-Host " $n entrees"
    return $n
}

# --- source 2 : registre ------------------------------------------------
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
            Add-App -Nom $nom.Value `
                    -Editeur $(if ($ed) { [string]$ed.Value } else { '' }) `
                    -Version $(if ($ver) { [string]$ver.Value } else { '' }) `
                    -Source 'registre' -Winget '' -TailleGo $taille
            $n++
        }
    }
    Write-Host " $n entrees"
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
            $nom = $p.Name
            # Les noms de paquets sont des identifiants techniques : on retire
            # le prefixe editeur pour obtenir quelque chose de lisible.
            $lisible = ($nom -replace '^(Microsoft|Microsoft\.)', 'Microsoft ').Trim()
            Add-App -Nom $lisible -Editeur $p.Publisher -Version $p.Version `
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
        foreach ($l in Get-Content $vdf -ErrorAction SilentlyContinue) {
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
            $contenu = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
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
    $dossier = Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
    if (-not (Test-Path $dossier)) {
        Write-Host " non installe, ignore" -ForegroundColor Yellow
        return 0
    }
    $n = 0
    Get-ChildItem -Path $dossier -Filter '*.item' -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $m = Get-Content $_.FullName -Raw -ErrorAction Stop | ConvertFrom-Json
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
function Read-Xbox {
    Write-Host "  Xbox / Game Pass..." -NoNewline
    # Les jeux Xbox sont des paquets APPX installes hors du dossier habituel :
    # c'est leur emplacement qui les distingue des applications du Store.
    $n = 0
    try {
        Get-AppxPackage -ErrorAction Stop |
            Where-Object { -not $_.IsFramework -and $_.InstallLocation -and
                           $_.InstallLocation -notlike "$env:ProgramFiles\WindowsApps*" } |
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
    Write-Host " $(@($vars).Count) relevee(s)"
    return $vars
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
    @{ cle='mozillafirefox';   nom='Profils Firefox';         chemins=@('%APPDATA%\Mozilla\Firefox\Profiles');            quoi='Marque-pages, extensions, cookies. Volumineux.' }
    @{ cle='mozillathunderbird';nom='Thunderbird';            chemins=@('%APPDATA%\Thunderbird\Profiles');                quoi='Comptes et courriels locaux. Volumineux.' }
    @{ cle='filezilla';        nom='FileZilla';               chemins=@('%APPDATA%\FileZilla');                           quoi='Sites enregistrés. Contient des mots de passe.' }
    @{ cle='winscp';           nom='WinSCP';                  chemins=@('%APPDATA%\WinSCP.ini');                          quoi='Sessions enregistrées.' }
    @{ cle='qbittorrent';      nom='qBittorrent';             chemins=@('%APPDATA%\qBittorrent','%LOCALAPPDATA%\qBittorrent'); quoi='Réglages et torrents en cours.' }
    @{ cle='obsstudio';        nom='OBS Studio';              chemins=@('%APPDATA%\obs-studio');                          quoi='Scènes, sources, profils d''encodage.' }
    @{ cle='vlcmediaplayer';   nom='VLC';                     chemins=@('%APPDATA%\vlc');                                 quoi='Réglages et équaliseur.' }
    @{ cle='krita';            nom='Krita';                   chemins=@('%APPDATA%\krita','%LOCALAPPDATA%\krita');        quoi='Brosses, espaces de travail.' }
    @{ cle='gimp';             nom='GIMP';                    chemins=@('%APPDATA%\GIMP');                                quoi='Brosses, greffons, préférences.' }
    @{ cle='blender';          nom='Blender';                 chemins=@('%APPDATA%\Blender Foundation\Blender');          quoi='Préférences, greffons, thèmes.' }
    @{ cle='unityhub';         nom='Unity';                   chemins=@('%APPDATA%\Unity','%APPDATA%\UnityHub');          quoi='Licences et réglages de l''éditeur.' }
    @{ cle='androidstudio';    nom='Android Studio';          chemins=@('%APPDATA%\Google');                              quoi='Réglages de l''IDE. Les SDK se retéléchargent.' }
    @{ cle='intellijidea';     nom='JetBrains';               chemins=@('%APPDATA%\JetBrains');                           quoi='Réglages communs aux IDE JetBrains.' }
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

function Get-TailleDossier {
    param([string]$Chemin)
    try {
        if (-not (Test-Path -LiteralPath $Chemin)) { return $null }
        $item = Get-Item -LiteralPath $Chemin -Force -ErrorAction Stop
        if (-not $item.PSIsContainer) { return [math]::Round($item.Length / 1MB, 2) }
        $somme = (Get-ChildItem -LiteralPath $Chemin -Recurse -File -Force -ErrorAction SilentlyContinue |
                  Measure-Object -Property Length -Sum).Sum
        if (-not $somme) { return 0 }
        return [math]::Round($somme / 1MB, 2)
    } catch { return $null }
}

function Read-Configs {
    param([string[]]$ClesInstallees = @())
    Write-Host "  dossiers de configuration..." -NoNewline
    $trouves = @()
    foreach ($regle in $ConfigsConnues) {
        # Une regle rattachee a un logiciel ne s'applique que s'il est installe :
        # sinon on proposerait d'emporter les restes d'un logiciel desinstalle.
        if ($regle.cle -and ($ClesInstallees -notcontains $regle.cle)) { continue }
        foreach ($brut in $regle.chemins) {
            $chemin = [Environment]::ExpandEnvironmentVariables($brut)
            # Un chemin non resolu garde ses %...% : inutile d'aller plus loin.
            if ($chemin -like '*%*') { continue }
            if (-not (Test-Path -LiteralPath $chemin)) { continue }
            $trouves += [ordered]@{
                nom      = $regle.nom
                chemin   = $chemin
                quoi     = $regle.quoi
                tailleMo = Get-TailleDossier -Chemin $chemin
                logiciel = $regle.cle
            }
        }
    }
    Write-Host " $(@($trouves).Count) trouve(s)"
    return $trouves
}
