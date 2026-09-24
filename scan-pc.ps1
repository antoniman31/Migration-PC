<#
.SYNOPSIS
    Inventorie les logiciels installes sur un PC Windows et produit un fichier JSON
    importable dans la checklist de migration (index.html).

.DESCRIPTION
    Le script interroge quatre sources et fusionne les resultats :
      - winget list        (identifiants d'installation officiels)
      - registre Uninstall (32 et 64 bits, machine et utilisateur)
      - applications du Microsoft Store (paquets APPX)
      - bibliotheques Steam (manifestes locaux)

    Aucune donnee ne quitte la machine : le script n'envoie rien sur le reseau,
    il ecrit uniquement un fichier JSON local que vous importez vous-meme.

.PARAMETER Sortie
    Chemin du fichier JSON produit. Par defaut inventaire-pc.json dans le dossier courant.

.PARAMETER SansStore
    Ignore les applications du Microsoft Store.

.PARAMETER SansJeux
    Ignore les bibliotheques Steam.

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
    [string]$Sortie = "inventaire-pc.json",
    [switch]$SansStore,
    [switch]$SansJeux,
    [switch]$ToutInclure
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

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
    $n = $n -replace '[^a-z0-9]', ''
    return $n
}

# ---------------------------------------------------------------- collecte

$resultats = @{}   # cle normalisee -> objet application

function Add-App {
    param(
        [string]$Nom, [string]$Editeur, [string]$Version,
        [string]$Source, [string]$Winget
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
            Add-App -Nom $nom.Value `
                    -Editeur $(if ($ed) { [string]$ed.Value } else { '' }) `
                    -Version $(if ($ver) { [string]$ver.Value } else { '' }) `
                    -Source 'registre' -Winget ''
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
                Add-App -Nom $matches[1] -Editeur 'Steam' -Version '' -Source 'Steam' -Winget ''
                $n++
            }
        }
    }
    Write-Host " $n jeux"
    return $n
}

# ---------------------------------------------------------------- execution

Write-Host ""
Write-Host "Inventaire des logiciels installes" -ForegroundColor Cyan
Write-Host "----------------------------------"

$null = Read-Winget
$null = Read-Registre
if (-not $SansStore) { $null = Read-Store }
if (-not $SansJeux)  { $null = Read-Steam }

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
}

$json = $inventaire | ConvertTo-Json -Depth 6
Set-Content -Path $Sortie -Value $json -Encoding UTF8

$avecWinget = @($apps | Where-Object { $_.winget }).Count
$chemin = (Resolve-Path $Sortie).Path

Write-Host ""
Write-Host "$($apps.Count) applications retenues, dont $avecWinget avec un identifiant winget." -ForegroundColor Green
Write-Host "Fichier ecrit : $chemin"
Write-Host ""
Write-Host "Etape suivante : ouvrir index.html, cliquer sur Importer, choisir ce fichier."
if (-not $ToutInclure) {
    Write-Host "Une entree manque ? Relancer avec -ToutInclure pour desactiver le filtrage."
}
Write-Host ""
