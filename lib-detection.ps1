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
    $dossier = Join-CheminSur $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
    if (-not $dossier -or -not (Test-Path $dossier)) {
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

$script:ExtensionsPrecieuses = @('*.jks', '*.keystore', '*.pfx', '*.p12')

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
    foreach ($f in (Get-ChildItem -LiteralPath $Racine -Recurse -File -Force `
                        -Include $script:ExtensionsPrecieuses -ErrorAction SilentlyContinue)) {
        if ($chrono.Elapsed.TotalSeconds -gt $BudgetSecondes) { break }
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

function Read-OutilsLangages {
    Write-Host "  outils npm et pip..." -NoNewline
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
    }
    Write-Host " $(@($trouves).Count) trouve(s)"
    return $trouves
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
