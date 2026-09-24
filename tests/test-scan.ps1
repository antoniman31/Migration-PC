# Tests de la detection partagee. Depuis que les trois scripts s'appuient sur
# lib-detection.ps1, il suffit de la charger : elle ne fait rien d'elle-meme.
#   pwsh -File tests/test-scan.ps1
$ToutInclure = $false
$resultats = @{}
$racineScan = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot/../lib-detection.ps1"
$script:ko=0
function ok($l,$a,$b){ if($a -eq $b){"  ok   $l -> $a"} else {"  FAIL $l -> $a (attendu $b)";$script:ko++} }

"--- classement ---"
ok 'Discord = comms'        (Get-Categorie -Nom 'Discord' -Editeur 'Discord Inc.') 'comms'
ok 'Chrome = bureautique'   (Get-Categorie -Nom 'Google Chrome' -Editeur 'Google') 'bureautique'
ok 'NVIDIA = pilotes'       (Get-Categorie -Nom 'NVIDIA App' -Editeur 'NVIDIA') 'pilotes'
ok 'Krita = media'          (Get-Categorie -Nom 'Krita' -Editeur 'KDE') 'media'
ok 'inconnu = system'       (Get-Categorie -Nom 'Bidule Machin' -Editeur 'Perso') 'system'

"--- filtrage ---"
ok 'VC++ exclu'             (Test-Exclu -Nom 'Microsoft Visual C++ 2015-2022 Redistributable (x64)') $true
ok 'mise a jour exclue'     (Test-Exclu -Nom 'Security Update for Windows') $true
ok 'vide exclu'             (Test-Exclu -Nom '') $true
ok 'app normale gardee'     (Test-Exclu -Nom 'Blender') $false

"--- normalisation ---"
ok '64-bit ignore'          (Get-Cle -Nom '7-Zip 24.08 (x64)') (Get-Cle -Nom '7-Zip')
ok 'casse ignoree'          (Get-Cle -Nom 'VLC media player') (Get-Cle -Nom 'vlc Media Player')
ok 'langue ignoree'         (Get-Cle -Nom 'Mozilla Firefox (x64 fr)') (Get-Cle -Nom 'Mozilla Firefox')
ok 'version a point ignoree' (Get-Cle -Nom 'Python 3.12.1 (64-bit)') (Get-Cle -Nom 'Python 3.13.0 (64-bit)')
ok 'prefixe v ignore'       (Get-Cle -Nom 'qBittorrent v4.6.2') (Get-Cle -Nom 'qBittorrent')

# Les numeros sans point echappaient a la regle des versions : deux lignes de
# checklist pour un seul logiciel.
ok 'numero de mise a jour ignore' (Get-Cle -Nom 'Java 8 Update 401') (Get-Cle -Nom 'Java 8 Update 411')
ok 'mais la version majeure reste' ((Get-Cle -Nom 'Java 8 Update 401') -ne (Get-Cle -Nom 'Java 11 Update 401')) $true

# La ponctuation porte parfois le nom. En l'effacant, « Notepad++ » devenait
# « Notepad » et les deux fusionnaient : l'un disparaissait de l'inventaire.
ok 'Notepad++ distinct de Notepad' ((Get-Cle -Nom 'Notepad++ (64-bit x64)') -ne (Get-Cle -Nom 'Notepad')) $true
ok 'Notepad++ distinct de Notepad3' ((Get-Cle -Nom 'Notepad++') -ne (Get-Cle -Nom 'Notepad3')) $true
ok 'C++ distinct de C'      ((Get-Cle -Nom 'Un outil C++') -ne (Get-Cle -Nom 'Un outil C')) $true
ok 'C# distinct de C'       ((Get-Cle -Nom 'C# Dev Kit') -ne (Get-Cle -Nom 'C Dev Kit')) $true
ok 'Notepad++ stable entre sources' (Get-Cle -Nom 'Notepad++ (64-bit x64)') (Get-Cle -Nom 'Notepad++')
ok 'aucune cle vide sur ces noms' (@('Notepad++','C#','7-Zip','3DMark','Paint.NET') |
    Where-Object { [string]::IsNullOrWhiteSpace((Get-Cle -Nom $_)) }).Count 0

"--- deux logiciels voisins ne fusionnent pas ---"
$script:resultats = @{}
Add-App -Nom 'Notepad++ (64-bit x64)' -Editeur 'Don Ho' -Version '8.6' -Source 'registre' -Winget 'Notepad++.Notepad++'
Add-App -Nom 'Notepad' -Editeur 'Microsoft' -Version '11.0' -Source 'store' -Winget 'Microsoft.WindowsNotepad'
ok 'deux entrees distinctes' $resultats.Count 2
ok 'chacune garde son winget' (@($resultats.Values | Where-Object { $_.winget -eq 'Notepad++.Notepad++' })).Count 1

"--- robustesse : ce qui faisait tomber le scan entier ---"
# Trois pieges, tous rencontres en executant le script pour de vrai, tous
# fatals : $ErrorActionPreference vaut 'Stop' — il le faut, un scan
# silencieusement incomplet serait pire — donc la moindre erreur non geree
# arretait tout, parfois APRES l ecriture du fichier.

# 1. Measure-Object sur une collection vide ne renvoie aucun objet, et lire
#    .Sum dessus est une erreur sous Set-StrictMode. Le cas n a rien
#    d exotique : peu de sources donnent la taille des applications.
ok 'somme de rien'              (Get-Somme @() 'tailleGo') 0
ok 'somme de nulls'             (Get-Somme @($null, $null) 'tailleGo') 0
ok 'propriete absente'          (Get-Somme @([pscustomobject]@{ nom = 'A' }) 'tailleGo') 0
ok 'melange avec et sans'       (Get-Somme @([pscustomobject]@{ tailleGo = 1.5 }, [pscustomobject]@{ nom = 'B' }) 'tailleGo') 1.5
ok 'toutes renseignees'         (Get-Somme @([pscustomobject]@{ tailleGo = 2 }, [pscustomobject]@{ tailleGo = 3 }) 'tailleGo') 5
ok 'valeurs a zero'             (Get-Somme @([pscustomobject]@{ tailleGo = 0 }) 'tailleGo') 0

# 2. Une source en panne emportait les six autres. Chacune est independante :
#    winget absent, Store indisponible, Epic pas installe sont des situations
#    normales, pas des raisons d abandonner l inventaire.
ok 'une source qui echoue rend 0' (Invoke-Detecteur -Nom 'test' -Bloc { throw 'panne simulee' }) 0
ok 'une source qui marche passe'  (Invoke-Detecteur -Nom 'test' -Bloc { 42 }) 42
$suite = 0
$null = Invoke-Detecteur -Nom 'test' -Bloc { throw 'panne' }
$suite = Invoke-Detecteur -Nom 'test' -Bloc { 7 }
ok 'et la suivante tourne quand meme' $suite 7

# 3. Join-Path s arrete net sur un chemin de depart vide : une seule variable
#    d environnement absente suffisait.
ok 'chemin sans base'           (Join-CheminSur '' 'Epic') $null
ok 'chemin sans base (null)'     (Join-CheminSur $null 'Epic') $null
# Un lecteur inexistant ne doit pas jeter : ce chemin part dans un Test-Path
# qui tranchera. « C: » n'existe pas sur la machine qui fait tourner ceci.
ok 'lecteur inexistant, pas d exception' ([string]::IsNullOrEmpty((Join-CheminSur 'C:\Base' 'Epic'))) $false
$base = [System.IO.Path]::GetTempPath().TrimEnd([System.IO.Path]::DirectorySeparatorChar)
ok 'chemin normal'              (Join-CheminSur $base 'Epic') (Join-Path $base 'Epic')

"--- materiel ---"
# Windows connait la machine : le bloc « Ma configuration » de la page n'a plus
# a etre saisi a la main. La lecture CIM ne tourne que sous Windows ; c'est la
# mise en forme qui decide de ce qui s'affiche, et elle se teste partout.
$m = Format-Materiel `
    -CarteMere  ([pscustomobject]@{ Manufacturer = 'ASUSTeK COMPUTER INC.'; Product = 'ROG STRIX B850-A' }) `
    -Processeur ([pscustomobject]@{ Name = 'AMD Ryzen 7 9800X3D 8-Core Processor' }) `
    -Cartes     @([pscustomobject]@{ Name = 'Microsoft Basic Display Adapter' },
                  [pscustomobject]@{ Name = 'NVIDIA GeForce RTX 5070 Ti' }) `
    -Barrettes  @([pscustomobject]@{ Capacity = 17179869184; ConfiguredClockSpeed = 6000; SMBIOSMemoryType = 34 },
                  [pscustomobject]@{ Capacity = 17179869184; ConfiguredClockSpeed = 6000; SMBIOSMemoryType = 34 }) `
    -Disques    @([pscustomobject]@{ Model = 'Samsung SSD 9100 PRO 2TB'; Size = 2000398934016 })
ok 'carte mere complete'      $m.cm 'ASUSTeK COMPUTER INC. ROG STRIX B850-A'
# « 8-Core Processor » n'apprend rien et allonge tous les intitules.
ok 'processeur sans le suffixe' $m.cpu 'AMD Ryzen 7 9800X3D'
# Le pilote d'affichage de base n'est pas une carte graphique : le nommer
# enverrait chercher son pilote au lieu de celui de la vraie carte.
ok 'la vraie carte graphique'  $m.gpu 'NVIDIA GeForce RTX 5070 Ti'
ok 'memoire totale et type'    $m.ram '32 Go DDR5 6000 MT/s'
# « Samsung SSD 9100 PRO 2TB 1863 Go » dirait deux fois la meme chose.
ok 'taille non repetee'        $m.ssd 'Samsung SSD 9100 PRO 2TB'

$vide = Format-Materiel -CarteMere $null -Processeur $null -Cartes @() -Barrettes @() -Disques @()
ok 'une machine muette ne jette pas' (@($vide.Keys)).Count 0
# Des barrettes qui ne declarent pas leur type : indexer un tableau vide jette.
$partiel = Format-Materiel -CarteMere $null -Processeur $null -Cartes @() `
    -Barrettes @([pscustomobject]@{ Capacity = 8589934592 }) -Disques @()
ok 'barrettes sans type declare' $partiel.ram '8 Go'
$virtuel = Format-Materiel -CarteMere $null -Processeur $null `
    -Cartes @([pscustomobject]@{ Name = 'Parsec Virtual Display' }) -Barrettes @() -Disques @()
ok 'un affichage virtuel est ignore' ($virtuel.Contains('gpu')) $false
$sansTaille = Format-Materiel -CarteMere $null -Processeur $null -Cartes @() -Barrettes @() `
    -Disques @([pscustomobject]@{ Model = 'KINGSTON SNV2S1000G'; Size = 1000204886016 })
ok 'taille ajoutee quand elle manque' $sansTaille.ssd 'KINGSTON SNV2S1000G 932 Go'

"`n--- peripheriques sans pilote ---"
# On ne devine pas quel pilote installer — il faudrait une table que personne
# ne tient a jour. On rapporte ce que Windows signale lui-meme, c'est-a-dire le
# point d'exclamation du gestionnaire de peripheriques.
$peripheriques = @(
    [pscustomobject]@{ Name = 'Controleur Ethernet'; PNPClass = $null;   ConfigManagerErrorCode = 28 }
    [pscustomobject]@{ Name = 'RTX 5070 Ti';         PNPClass = 'Display'; ConfigManagerErrorCode = 0 }
    [pscustomobject]@{ Name = 'Realtek Audio';       PNPClass = 'MEDIA'; ConfigManagerErrorCode = 10 }
    [pscustomobject]@{ Name = 'Webcam desactivee';   PNPClass = 'Camera'; ConfigManagerErrorCode = 22 }
    [pscustomobject]@{ Name = 'Sans code';           PNPClass = 'Net' }
)
$pil = @(Format-Pilotes -Peripheriques $peripheriques)
ok 'seuls les problemes de pilote'  $pil.Count 2
ok 'un peripherique sain est ignore' (@($pil | Where-Object { $_.nom -match '5070' })).Count 0
# Code 22 : desactive par l'utilisateur. Il n'y a rien a reparer.
ok 'un peripherique desactive aussi' (@($pil | Where-Object { $_.nom -match 'Webcam' })).Count 0
ok 'sans code, rien'                 (@($pil | Where-Object { $_.nom -eq 'Sans code' })).Count 0
ok 'le probleme est nomme'           (@($pil | Where-Object { $_.nom -match 'Ethernet' })[0].probleme) 'aucun pilote installe'
ok 'liste vide, rien'                (@(Format-Pilotes -Peripheriques @())).Count 0

"--- la table des configurations ne doit pas se marcher dessus ---"
# sauvegarder-configs.ps1 derive le nom du sous-dossier de copie du nom de
# l entree, en remplacant ce qui n est pas un caractere de nom de fichier.
# Deux entrees qui retombent sur le meme nom se recouvriraient en silence, et
# l index decrirait deux fois le meme dossier.
$nomsDeDossier = @($ConfigsConnues | ForEach-Object { ($_.nom -replace '[^\w\- ]', '_').Trim() })
ok 'chaque entree a un nom'          (@($ConfigsConnues | Where-Object { -not $_.nom }).Count) 0
ok 'aucun nom de dossier vide'       (@($nomsDeDossier | Where-Object { -not $_ }).Count) 0
ok 'aucune collision de dossier'     ($nomsDeDossier.Count) (@($nomsDeDossier | Sort-Object -Unique).Count)
# Le modele garde ses variables : c est lui qui permet de restaurer sous un
# autre nom d utilisateur. Un chemin en dur dans la table casserait cela.
$enDur = @($ConfigsConnues | Where-Object { @($_.chemins | Where-Object { $_ -notmatch '%' }).Count -gt 0 })
ok 'aucun chemin en dur dans la table' $enDur.Count 0

"--- dossiers de configuration ---"
# Un dossier de config ne se devine pas : il est cherche la ou la table le dit,
# et seulement si le logiciel correspondant est installe.
$racine = Join-Path ([System.IO.Path]::GetTempPath()) ("cfg-" + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path (Join-Path $racine 'profil\.ssh') -Force
$null = New-Item -ItemType Directory -Path (Join-Path $racine 'appdata\Code\User') -Force
$null = New-Item -ItemType Directory -Path (Join-Path $racine 'appdata\obsidian') -Force
Set-Content -Path (Join-Path $racine 'profil\.ssh\id_ed25519') -Value 'secret'
# -Encoding Byte n'existe plus en PowerShell 7 : on passe par .NET, qui se
# comporte pareil des deux cotes.
$bloc = New-Object byte[] 524288
[System.IO.File]::WriteAllBytes((Join-Path $racine 'appdata\Code\User\settings.json'), $bloc)

[Environment]::SetEnvironmentVariable('USERPROFILE', (Join-Path $racine 'profil'))
[Environment]::SetEnvironmentVariable('APPDATA', (Join-Path $racine 'appdata'))
[Environment]::SetEnvironmentVariable('LOCALAPPDATA', (Join-Path $racine 'local'))

$avec = @(Read-Configs -ClesInstallees @('visualstudiocode'))
ok 'les cles SSH sortent sans logiciel declare' (@($avec | Where-Object { $_.nom -eq 'Clés SSH' })).Count 1
ok 'VS Code sort car installe'                 (@($avec | Where-Object { $_.nom -eq 'Visual Studio Code' })).Count 1
# Le dossier d'Obsidian existe, mais Obsidian n'est pas installe : ce sont des
# restes, pas une configuration a emporter.
ok 'Obsidian non installe est ignore'          (@($avec | Where-Object { $_.nom -eq 'Obsidian' })).Count 0
ok 'la taille est mesuree'                     ((@($avec | Where-Object { $_.nom -eq 'Visual Studio Code' })[0].tailleMo) -gt 0) $true

$sans = @(Read-Configs -ClesInstallees @())
ok 'sans logiciel, seules les regles libres sortent' (@($sans | Where-Object { $_.cle })).Count 0
ok 'les cles SSH restent proposees'            (@($sans | Where-Object { $_.nom -eq 'Clés SSH' })).Count 1

# Un chemin absent n'est jamais retenu, meme si la table le connait.
ok 'un dossier absent n est pas invente'       (@($avec | Where-Object { -not (Test-Path -LiteralPath $_.chemin) })).Count 0
ok 'chaque entree porte un chemin'             (@($avec | Where-Object { [string]::IsNullOrWhiteSpace($_.chemin) })).Count 0
ok 'et une explication'                        (@($avec | Where-Object { [string]::IsNullOrWhiteSpace($_.quoi) })).Count 0

ok 'taille d un dossier absent = null'         (Get-TailleDossier -Chemin (Join-Path $racine 'nexiste-pas')) $null
Remove-Item -LiteralPath $racine -Recurse -Force -ErrorAction SilentlyContinue

"--- fusion des sources ---"
$script:resultats = @{}
Add-App -Nom 'Mozilla Firefox (x64 fr)' -Editeur 'Mozilla' -Version '140.0' -Source 'registre' -Winget ''
Add-App -Nom 'Mozilla Firefox' -Editeur '' -Version '' -Source 'winget' -Winget 'Mozilla.Firefox'
ok 'fusion en une entree'   $resultats.Count 1
$f = $resultats.Values | Select-Object -First 1
ok 'winget recupere'        $f.winget 'Mozilla.Firefox'
ok 'editeur conserve'       $f.editeur 'Mozilla'
ok 'sources cumulees'       ($f.source -like '*registre*' -and $f.source -like '*winget*') $true
Add-App -Nom 'Microsoft Visual C++ 2022 Redistributable' -Editeur 'MS' -Version '1' -Source 'registre' -Winget ''
ok 'exclu non ajoute'       $resultats.Count 1

"--- parsing de la sortie winget ---"
$script:resultats = @{}
$faux = @'
Name                 Id                        Version      Available Source
-------------------------------------------------------------------------------
7-Zip 24.08 (x64)    7zip.7zip                 24.08                  winget
Git                  Git.Git                   2.47.0                 winget
Un logiciel maison   ARP\Machine\X64\bidule    1.0
Blender              BlenderFoundation.Blender 4.2.3        4.3.0     winget
'@
# on remplace l'appel externe par la sortie simulee
function Invoke-WingetBrut { $faux }
$lignes = $faux -split "`r?`n"
$entete = $lignes | Where-Object { $_ -match '^\s*(Name|Nom)\s+(Id|ID)\s+' } | Select-Object -First 1
ok 'entete trouvee'         ($null -ne $entete) $true
$posId = $entete.IndexOf('Id'); $posVer = $entete.IndexOf('Version')
$debut=$false; $n=0
foreach($l in $lignes){
  if($l -match '^-{5,}'){$debut=$true;continue}
  if(-not $debut -or $l.Trim().Length -eq 0 -or $l.Length -le $posId){continue}
  $nom=$l.Substring(0,$posId).Trim(); $reste=$l.Substring($posId); $d=$posVer-$posId
  if($reste.Length -gt $d){ $id=$reste.Substring(0,$d).Trim(); $ver=($reste.Substring($d).Trim() -split '\s+')[0] }
  else { $id=$reste.Trim(); $ver='' }
  $valide = ($id -match '^[A-Za-z0-9][A-Za-z0-9._-]*\.[A-Za-z0-9._-]+$')
  Add-App -Nom $nom -Editeur '' -Version $ver -Source 'winget' -Winget $(if($valide){$id}else{''})
  $n++
}
ok 'lignes lues'            $n 4
ok 'apps retenues'          $resultats.Count 4
$z = $resultats[(Get-Cle -Nom '7-Zip')]
ok 'id 7-Zip'               $z.winget '7zip.7zip'
ok 'version 7-Zip'          $z.version '24.08'
$b = $resultats[(Get-Cle -Nom 'Blender')]
ok 'version sans Available' $b.version '4.2.3'
ok 'categorie Blender'      $b.cat 'media'
$m = $resultats[(Get-Cle -Nom 'Un logiciel maison')]
ok 'id ARP rejete'          $m.winget ''

"--- le fichier depose a cote de la page ---"
# Le nom de la variable globale est ecrit dans ecrire-resultat.ps1 d un cote et
# lu dans index.html de l autre. Rien ne verifiait que les deux parlent de la
# meme chose : renommer l un des deux aurait casse le remplissage automatique
# sans faire tomber un seul test.
. (Join-Path $racineScan 'ecrire-resultat.ps1')
$bacEcr = Join-Path ([System.IO.Path]::GetTempPath()) ("mpc-ecr-" + (Get-Random))
New-Item -ItemType Directory -Path $bacEcr -Force | Out-Null
try {
    Set-Content -LiteralPath (Join-Path $bacEcr 'index.html') -Value '<html></html>'
    $faux = [ordered]@{ type='inventaire-migration-pc'; version=1
                        machine=[ordered]@{ os='Windows 11'; nom='PC' }
                        apps=@([ordered]@{ nom='Clés SSH'; cat='system' }) }
    Write-ResultatPourSite -Donnees $faux -DossierScript $bacEcr -NePasOuvrir *> $null
    $depose = Join-Path $bacEcr 'resultat-scan.js'
    ok 'le fichier est depose'      (Test-Path -LiteralPath $depose) $true
    $contenu = Get-Content -LiteralPath $depose -Raw
    ok 'il pose la variable attendue' ($contenu.TrimStart([char]0xFEFF).StartsWith('window.MIGRATION_PC_SCAN=')) $true
    ok 'et se termine par un point-virgule' ($contenu.TrimEnd().EndsWith(';')) $true
    # La page lit cette variable-la : les deux cotes doivent s accorder.
    $page = Get-Content -LiteralPath (Join-Path $racineScan 'index.html') -Raw
    ok 'la page lit cette variable'  ($page -match 'window\.MIGRATION_PC_SCAN') $true
    # Le JSON doit se relire, accents compris.
    $json = $contenu.Substring($contenu.IndexOf('=') + 1).TrimEnd()
    $json = $json.Substring(0, $json.Length - 1)
    $relu = $json | ConvertFrom-Json
    ok 'le JSON se relit'            $relu.type 'inventaire-migration-pc'
    ok 'les accents survivent'       $relu.apps[0].nom 'Clés SSH'

    # Une cle protegee en ecriture ne doit pas faire finir en rouge un scan
    # reussi : le JSON est deja ecrit, ce depot n est qu un confort.
    $verrou = Join-Path $bacEcr 'verrou'
    New-Item -ItemType Directory -Path $verrou -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $verrou 'index.html') -Value '<html></html>'
    # On occupe le nom du fichier par un DOSSIER : l ecriture echouera a coup sur.
    New-Item -ItemType Directory -Path (Join-Path $verrou 'resultat-scan.js') -Force | Out-Null
    $aPlante = $false
    try { Write-ResultatPourSite -Donnees $faux -DossierScript $verrou -NePasOuvrir *> $null }
    catch { $aPlante = $true }
    ok 'une ecriture impossible ne fait pas tomber le scan' $aPlante $false
} finally {
    Remove-Item $bacEcr -Recurse -Force -ErrorAction SilentlyContinue
}

"--- JSON produit ---"
$inv=[ordered]@{type='inventaire-migration-pc';version=1;genere=(Get-Date).ToString('o');
  machine=[ordered]@{os='Windows 11 Pro';nom='TEST'};apps=@($resultats.Values | Sort-Object {$_.nom})}
$j=$inv | ConvertTo-Json -Depth 6
Set-Content -Path (Join-Path ([System.IO.Path]::GetTempPath()) "inv-test.json") -Value $j -Encoding UTF8
$relu = Get-Content (Join-Path ([System.IO.Path]::GetTempPath()) "inv-test.json") -Raw | ConvertFrom-Json
ok 'type'                   $relu.type 'inventaire-migration-pc'
ok 'apps serialisees'       $relu.apps.Count 4
ok 'champs presents'        ($null -ne $relu.apps[0].nom -and $null -ne $relu.apps[0].cat) $true

"--- taille sur disque ---"
$script:resultats = @{}
Add-App -Nom 'Un gros jeu' -Editeur 'Steam' -Version '' -Source 'Steam' -Winget '' -TailleGo 74.5
$j = $resultats.Values | Select-Object -First 1
ok 'taille conservee'        $j.tailleGo 74.5
# Une seconde source qui ne connait pas la taille ne doit pas l'effacer.
Add-App -Nom 'Un gros jeu' -Editeur '' -Version '1.0' -Source 'registre' -Winget ''
ok 'taille non ecrasee'      ($resultats.Values | Select-Object -First 1).tailleGo 74.5
# Et une source qui la connait complete une entree qui ne l'avait pas.
$script:resultats = @{}
Add-App -Nom 'Autre jeu' -Editeur '' -Version '' -Source 'winget' -Winget 'X.Y'
Add-App -Nom 'Autre jeu' -Editeur '' -Version '' -Source 'Steam' -Winget '' -TailleGo 12.25
ok 'taille completee ensuite' ($resultats.Values | Select-Object -First 1).tailleGo 12.25
ok 'sans taille reste nul'   ($null -eq (& { $script:resultats = @{}; Add-App -Nom 'Sans taille' -Editeur '' -Version '' -Source 'registre' -Winget ''; ($resultats.Values | Select-Object -First 1).tailleGo })) $true

"--- manifeste Epic simule ---"
# Le format est du JSON : on verifie la lecture et le filtrage des non-jeux.
$dossierEpic = Join-Path ([System.IO.Path]::GetTempPath()) "epic-test-$PID"
New-Item -ItemType Directory -Path $dossierEpic -Force | Out-Null
@'
{"DisplayName":"Un Jeu Epic","AppVersionString":"1.4.2","InstallSize":32212254720,"AppCategories":["games","applications"]}
'@ | Set-Content (Join-Path $dossierEpic 'jeu.item') -Encoding UTF8
@'
{"DisplayName":"Un Greffon","AppVersionString":"1.0","InstallSize":1048576,"AppCategories":["plugins"]}
'@ | Set-Content (Join-Path $dossierEpic 'greffon.item') -Encoding UTF8

$script:resultats = @{}
$lus = 0
Get-ChildItem -Path $dossierEpic -Filter '*.item' | ForEach-Object {
    $m = Get-Content $_.FullName -Raw | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace($m.DisplayName)) { return }
    if ($m.PSObject.Properties['AppCategories'] -and $m.AppCategories -and
        ($m.AppCategories -notcontains 'games')) { return }
    $t = if ($m.InstallSize) { [math]::Round($m.InstallSize / 1GB, 2) } else { $null }
    Add-App -Nom $m.DisplayName -Editeur 'Epic Games' -Version $m.AppVersionString -Source 'Epic Games' -Winget '' -TailleGo $t
    $lus++
}
ok 'greffon ecarte'          $lus 1
ok 'jeu Epic retenu'         $resultats.Count 1
$e = $resultats.Values | Select-Object -First 1
ok 'taille Epic en Go'       $e.tailleGo 30
ok 'version Epic'            $e.version '1.4.2'
ok 'jeu Epic classe jeux'    $e.cat 'jeux'
Remove-Item $dossierEpic -Recurse -Force

"--- compter sans se tromper de forme ---"
# @($x).Count applique a un dictionnaire rend 1, toujours : le scan annoncait
# « 1 variable d environnement relevee » quel que soit le nombre reel. Le bug
# ne se voyait qu'en executant le script.
$dico = [ordered]@{ 'JAVA_HOME'='C:/java'; 'GOPATH'='C:/go'; 'PATH (utilisateur)'='C:/bin' }
ok 'le piege existe toujours'    (@($dico).Count) 1
ok 'un dictionnaire est compte'  (Get-Nombre $dico) 3
ok 'un dictionnaire vide vaut 0' (Get-Nombre ([ordered]@{})) 0
ok 'un tableau reste compte'     (Get-Nombre @('a','b')) 2
ok 'un seul element aussi'       (Get-Nombre @('a')) 1
ok 'un element nu aussi'         (Get-Nombre 'a') 1
ok 'rien vaut 0'                 (Get-Nombre $null) 0

"--- variables d'environnement ---"
# Read-Variables lit l'environnement reel : hors Windows la portee « User »
# n'existe pas, donc on ne peut pas verifier ce qu'elle retient. Ce qu'on peut
# verifier, c'est qu'elle rend bien un dictionnaire comptable et qu'elle ne
# tombe pas.
$lues = Read-Variables
ok 'un dictionnaire est rendu'   ($lues -is [System.Collections.IDictionary]) $true
ok 'comptable sans erreur'       ((Get-Nombre $lues) -ge 0) $true
# Les variables standard de Windows ne doivent jamais partir dans l inventaire :
# elles ne disent rien de la machine et polluent l onglet Donnees.
$fuite = @($lues.Keys | Where-Object { $_ -in @('PATH','TEMP','WINDIR','USERPROFILE','APPDATA') })
ok 'aucune variable standard ne fuit' $fuite.Count 0

"--- inventaire avec les nouveaux champs ---"
$script:resultats = @{}
Add-App -Nom 'App test' -Editeur 'X' -Version '1' -Source 'registre' -Winget 'X.App' -TailleGo 2.5
$inv2 = [ordered]@{ type='inventaire-migration-pc'; version=1; genere=(Get-Date).ToString('o')
  machine=[ordered]@{os='Windows 11';nom='T'}; apps=@($resultats.Values)
  variables=[ordered]@{ 'JAVA_HOME'='C:/java'; 'PATH (utilisateur)'='C:/bin' } }
$j2 = $inv2 | ConvertTo-Json -Depth 6
$relu2 = $j2 | ConvertFrom-Json
ok 'tailleGo serialisee'     $relu2.apps[0].tailleGo 2.5
ok 'variables serialisees'   $relu2.variables.JAVA_HOME 'C:/java'
ok 'nom de variable avec espace' $relu2.variables.'PATH (utilisateur)' 'C:/bin'

if($script:ko){"`n$($script:ko) TEST(S) EN ECHEC"; exit 1} else {"`nTOUS LES TESTS POWERSHELL PASSENT"}
