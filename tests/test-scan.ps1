# Tests de la detection partagee. Depuis que les trois scripts s'appuient sur
# lib-detection.ps1, il suffit de la charger : elle ne fait rien d'elle-meme.
#   pwsh -File tests/test-scan.ps1
$ToutInclure = $false
$resultats = @{}
$racineScan = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot/../scripts/lib-detection.ps1"
$script:ko=0
function ok($l,$a,$b){ if($a -eq $b){"  ok   $l -> $a"} else {"  FAIL $l -> $a (attendu $b)";$script:ko++} }
# Les detecteurs recoivent des objets CIM ; ici on fabrique l'equivalent a la
# main, pour les exercer sans Windows.
function Obj($h){ $o = New-Object PSObject; foreach($k in $h.Keys){ $o | Add-Member -NotePropertyName $k -NotePropertyValue $h[$k] }; return $o }

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

# ---- les trois qui servent a retrouver un pilote ----
# Le reseau d'abord : c'est le pilote dont depend la recherche de tous les
# autres. Une machine de developpement empile les cartes virtuelles, et prendre
# la premiere venue enverrait chercher le pilote d'un adaptateur Hyper-V.
$res = Format-Materiel -Reseau @(
    [pscustomobject]@{ Name = 'Hyper-V Virtual Ethernet Adapter'; PhysicalAdapter = $true },
    [pscustomobject]@{ Name = 'Realtek Gaming 2.5GbE Family Controller'; PhysicalAdapter = $true },
    [pscustomobject]@{ Name = 'Intel(R) Wi-Fi 6E AX211 160MHz'; PhysicalAdapter = $true },
    [pscustomobject]@{ Name = 'Bluetooth Device (Personal Area Network)'; PhysicalAdapter = $true },
    [pscustomobject]@{ Name = 'WAN Miniport (IP)'; PhysicalAdapter = $false })
ok 'la carte filaire reelle'   $res.eth  'Realtek Gaming 2.5GbE Family Controller'
ok 'et le Wi-Fi a part'        $res.wifi 'Intel(R) Wi-Fi 6E AX211 160MHz'
# Un fixe sans Wi-Fi ne doit pas se retrouver avec un champ invente.
$fixe = Format-Materiel -Reseau @([pscustomobject]@{ Name = 'Intel(R) Ethernet Controller I225-V'; PhysicalAdapter = $true })
ok 'un fixe n a pas de Wi-Fi'  ($fixe.Contains('wifi')) $false

# La sortie audio d'une carte graphique passe par HDMI et arrive avec le pilote
# de la carte : la nommer enverrait chercher un pilote qu'on a deja.
$aud = Format-Materiel -Audio @(
    [pscustomobject]@{ Name = 'NVIDIA High Definition Audio' },
    [pscustomobject]@{ Name = 'Realtek(R) Audio' })
ok 'la puce de la carte mere'  $aud.audio 'Realtek(R) Audio'

# Get-CimInstance rend un DateTime ; les formes anciennes rendent la chaine CIM
# brute, que [datetime] refuse. Perdre la date sur une machine qui repond
# autrement que prevu serait dommage : c'est elle qui dit si le BIOS est vieux.
$b1 = Format-Materiel -Bios @([pscustomobject]@{ SMBIOSBIOSVersion = '1402'; ReleaseDate = '20250311000000.000000+000' })
ok 'date CIM brute lue'        $b1.bios '1402 (2025-03-11)'
$b2 = Format-Materiel -Bios @([pscustomobject]@{ SMBIOSBIOSVersion = 'F31'; ReleaseDate = ([datetime]'2024-06-02') })
ok 'date DateTime lue'         $b2.bios 'F31 (2024-06-02)'
$b3 = Format-Materiel -Bios @([pscustomobject]@{ SMBIOSBIOSVersion = '2.1' })
ok 'sans date, la version seule' $b3.bios '2.1'
$b4 = Format-Materiel -Bios @([pscustomobject]@{ SMBIOSBIOSVersion = '' })
ok 'sans version, rien'        ($b4.Contains('bios')) $false

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

"--- les lanceurs de jeux qui manquaient ---"
# Ubisoft tient ses installations dans une cle qui porte le dossier mais pas le
# nom : le nom se deduit donc du dossier, faute de mieux.
$ub = @(Format-JeuxUbisoft -Entrees @(
    [ordered]@{ dossier = 'D:\Ubisoft\Assassins Creed Mirage' },
    [ordered]@{ dossier = 'C:\Program Files\Ubisoft\Far Cry 6\' },
    [ordered]@{ dossier = '' },
    [ordered]@{ autre = 'sans dossier' },
    $null))
ok 'deux jeux Ubisoft'            $ub.Count 2
ok 'le nom vient du dossier'      $ub[0].nom 'Assassins Creed Mirage'
ok 'une barre finale ne gene pas' $ub[1].nom 'Far Cry 6'

# L EA App ne tient pas de registre : chaque jeu depose un
# __Installer\installerdata.xml dans son dossier. C est ce fichier qui
# distingue un jeu d un dossier quelconque pose au meme endroit.
$bacE = Join-Path ([System.IO.Path]::GetTempPath()) ("mpc-ea-" + (Get-Random))
try {
    New-Item -ItemType Directory -Path (Join-Path $bacE 'EA Games\Le Jeu\__Installer') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $bacE 'EA Games\Le Jeu\__Installer\installerdata.xml') -Value '<DiPManifest/>'
    New-Item -ItemType Directory -Path (Join-Path $bacE 'EA Games\Pas un jeu') -Force | Out-Null
    $ea = @(Format-JeuxEa -Racines @((Join-Path $bacE 'EA Games'), (Join-Path $bacE 'nexistepas'), ''))
    ok 'un jeu EA est vu'             $ea.Count 1
    ok 'et il porte le nom du dossier' $ea[0].nom 'Le Jeu'
} finally {
    Remove-Item $bacE -Recurse -Force -ErrorAction SilentlyContinue
}

"--- additionner des dictionnaires ---"
# Les elements du projet sont des dictionnaires ordonnes, pas des objets :
# PSObject.Properties n y voit rien et Measure-Object non plus. La somme rendait
# donc 0 en silence, et la taille des applications comme celle des dossiers de
# configuration n ont jamais ete affichees.
$dicos = @([ordered]@{ nom = 'a'; tailleMo = 10 }, [ordered]@{ nom = 'b'; tailleMo = 5 })
ok 'somme sur des dictionnaires' (Get-Somme $dicos 'tailleMo') 15
$objets = @([pscustomobject]@{ tailleMo = 10 }, [pscustomobject]@{ tailleMo = 5 })
ok 'somme sur des objets'        (Get-Somme $objets 'tailleMo') 15
ok 'propriete absente vaut 0'    (Get-Somme $dicos 'nexistepas') 0
ok 'melange de presents et absents' (Get-Somme @([ordered]@{ t = 3 }, [ordered]@{ u = 9 }) 't') 3
ok 'valeur vide ignoree'         (Get-Somme @([ordered]@{ t = '' }, [ordered]@{ t = 4 }) 't') 4
ok 'valeur non numerique ignoree' (Get-Somme @([ordered]@{ t = 'beaucoup' }, [ordered]@{ t = 2 }) 't') 2
ok 'rien vaut 0'                 (Get-Somme @() 't') 0

"--- ce qui est un jeu Xbox, et ce qui ne l est pas ---"
# Le filtre d origine prenait « tout paquet APPX hors de %ProgramFiles% » :
# Windows range ses propres composants dans C:\Windows\SystemApps, qui passait
# donc. L inventaire se remplissait de composants systeme etiquetes « Xbox ».
# On fixe %ProgramFiles% pour que le test dise la meme chose partout, et on le
# remet apres : sous Windows, il est reel et sert au reste du script.
$programFilesAvant = $env:ProgramFiles
$env:ProgramFiles = 'C:\Program Files'
function Paquet($nom, $ou, $cadre = $false, $signature = 'Store') {
    [pscustomobject]@{ Name = $nom; InstallLocation = $ou; IsFramework = $cadre; SignatureKind = $signature }
}
ok 'un jeu sur un autre disque'   (Test-JeuXbox (Paquet 'Editeur.UnJeu' 'D:\WindowsApps\Editeur.UnJeu_1.0')) $true
ok 'un jeu dans XboxGames'        (Test-JeuXbox (Paquet 'Editeur.Forza' 'E:\XboxGames\Forza\Content')) $true
ok 'une appli du Store, non'      (Test-JeuXbox (Paquet 'Microsoft.Todos' 'C:\Program Files\WindowsApps\Microsoft.Todos_2')) $false
ok 'un composant systeme, non'    (Test-JeuXbox (Paquet 'Microsoft.SecHealthUI' 'C:\Windows\SystemApps\Microsoft.SecHealthUI' $false 'System')) $false
ok 'un composant hors magasin, non' (Test-JeuXbox (Paquet 'Machin.Truc' 'C:\Windows\SystemApps\Machin.Truc')) $false
ok 'un cadre applicatif, non'     (Test-JeuXbox (Paquet 'Microsoft.VCLibs' 'D:\WindowsApps\Microsoft.VCLibs' $true)) $false
ok 'sans emplacement, non'        (Test-JeuXbox (Paquet 'Sans.Lieu' '')) $false
ok 'rien du tout, non'            (Test-JeuXbox $null) $false
$env:ProgramFiles = $programFilesAvant

"--- l editeur rendu par le Store ---"
# Get-AppxPackage rend un nom distingue de certificat. Recopie tel quel, ce
# pave partait dans l inventaire et s affichait sous le nom du logiciel.
ok 'le CN est extrait' (Get-EditeurLisible 'CN=Microsoft Corporation, O=Microsoft Corporation, L=Redmond, S=Washington, C=US') 'Microsoft Corporation'
ok 'meme si le CN n est pas en tete' (Get-EditeurLisible 'O=Truc, CN=Machin SARL, C=FR') 'Machin SARL'
ok 'un editeur normal passe tel quel' (Get-EditeurLisible 'Igor Pavlov') 'Igor Pavlov'
ok 'rien reste rien'                  (Get-EditeurLisible '') ''
# Le classement s appuie sur l editeur : il doit continuer a marcher apres.
ok 'le classement survit' (Get-Categorie -Nom 'Un truc' -Editeur (Get-EditeurLisible 'CN=NVIDIA Corporation, C=US')) 'pilotes'

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
. (Join-Path $racineScan 'scripts/ecrire-resultat.ps1')
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
    $contenu = Get-Content -LiteralPath $depose -Raw -Encoding UTF8
    ok 'il pose la variable attendue' ($contenu.TrimStart([char]0xFEFF).StartsWith('window.MIGRATION_PC_SCAN=')) $true
    ok 'et se termine par un point-virgule' ($contenu.TrimEnd().EndsWith(';')) $true
    # La page lit cette variable-la : les deux cotes doivent s accorder.
    $page = Get-Content -LiteralPath (Join-Path $racineScan 'index.html') -Raw -Encoding UTF8
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
$relu = Get-Content (Join-Path ([System.IO.Path]::GetTempPath()) "inv-test.json") -Raw -Encoding UTF8 | ConvertFrom-Json
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
    $m = Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
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


"--- winget : identifiants installables ---"
ok 'catalogue accepte'      (Test-IdWingetInstallable -Id 'Mozilla.Firefox') $true
ok 'ARP refuse'             (Test-IdWingetInstallable -Id 'ARP\Machine\X64\{1234-5678}') $false
ok 'MSIX refuse'            (Test-IdWingetInstallable -Id 'MSIX\Microsoft.Paint_8wekyb3d8bbwe') $false
ok 'minuscules refusees aussi' (Test-IdWingetInstallable -Id 'arp\Machine\X64\{9}') $false
ok 'sans point refuse'      (Test-IdWingetInstallable -Id 'Firefox') $false
ok 'vide refuse'            (Test-IdWingetInstallable -Id '') $false

"--- winget : lecture de l'export ---"
$exp = Read-ExportWinget -Json (Get-Content -LiteralPath "$PSScriptRoot/winget-export-exemple.json" -Raw -Encoding UTF8)
# Le fichier d'exemple contient 8 entrees dont un doublon de 7zip : la lecture
# ne deduplique pas, c'est Merge-IdsWinget qui s'en charge.
ok 'export lu'              (Get-Nombre $exp) 8
ok 'premier identifiant'    $exp[0].id '7zip.7zip'
ok 'version quand presente' (@($exp | Where-Object { $_.id -eq 'Mozilla.Firefox' })[0].version) '142.0'
ok 'JSON vide sans erreur'  (Get-Nombre (Read-ExportWinget -Json '')) 0
ok 'JSON casse sans erreur' (Get-Nombre (Read-ExportWinget -Json '{pas du json')) 0
ok 'ARP filtre a la lecture' (Get-Nombre (Read-ExportWinget -Json '{"Sources":[{"Packages":[{"PackageIdentifier":"ARP\\Machine\\X64\\{1}"}]}]}')) 0

"--- winget : rapprochement des identifiants ---"
ok 'editeur+produit'        ((Get-ClesCandidatesWinget -Id 'Mozilla.Firefox') -contains (Get-Cle -Nom 'Mozilla Firefox')) $true
ok 'produit seul'           ((Get-ClesCandidatesWinget -Id '7zip.7zip') -contains (Get-Cle -Nom '7-Zip')) $true
ok 'couple complet en premier' (Get-ClesCandidatesWinget -Id 'Mozilla.Firefox')[0] (Get-Cle -Nom 'Mozilla Firefox')

# Un inventaire neuf : deux logiciels connus du registre, sans identifiant.
$resultats = @{}
Add-App -Nom 'Mozilla Firefox (x64 fr)' -Editeur 'Mozilla' -Version '142.0' -Source 'registre' -Winget ''
Add-App -Nom '7-Zip 24.08 (x64)' -Editeur 'Igor Pavlov' -Version '24.08' -Source 'registre' -Winget ''
$avant = $resultats.Count
$r = Merge-IdsWinget -Entrees @(
    [ordered]@{ id = 'Mozilla.Firefox'; version = '142.0' },
    [ordered]@{ id = '7zip.7zip';       version = '24.08' },
    [ordered]@{ id = 'Valve.Steam';     version = '' }
)
ok 'deux identifiants poses' $r.poses 2
ok 'une ligne ajoutee'       $r.crees 1
ok 'Firefox a son id'        $resultats[(Get-Cle -Nom 'Mozilla Firefox')].winget 'Mozilla.Firefox'
ok '7-Zip a son id'          $resultats[(Get-Cle -Nom '7-Zip')].winget '7zip.7zip'
ok 'Steam cree'              $resultats[(Get-Cle -Nom 'Steam')].winget 'Valve.Steam'
ok 'Steam nomme lisiblement' $resultats[(Get-Cle -Nom 'Steam')].nom 'Steam'
ok 'une seule ligne en plus' ($resultats.Count - $avant) 1
ok 'source completee'        ($resultats[(Get-Cle -Nom 'Mozilla Firefox')].source -like '*winget*') $true

# Rejouer le meme export ne doit rien reposer ni rien recreer.
$r2 = Merge-IdsWinget -Entrees @([ordered]@{ id = 'Mozilla.Firefox'; version = '142.0' })
ok 'rejeu sans effet (pose)' $r2.poses 0
ok 'rejeu sans effet (cree)' $r2.crees 0

"--- adresse officielle au registre ---"
function EntreeReg($h){ $o = New-Object PSObject; foreach($k in $h.Keys){ $o | Add-Member -NotePropertyName $k -NotePropertyValue $h[$k] }; return $o }
ok 'URLInfoAbout lu'        (Get-LienEditeur -Entree (EntreeReg @{ URLInfoAbout = 'https://www.videolan.org/' })) 'https://www.videolan.org/'
ok 'HelpLink en secours'    (Get-LienEditeur -Entree (EntreeReg @{ HelpLink = 'https://support.mozilla.org' })) 'https://support.mozilla.org'
ok 'URLInfoAbout prioritaire' (Get-LienEditeur -Entree (EntreeReg @{ URLInfoAbout='https://a.example'; HelpLink='https://b.example' })) 'https://a.example'
ok 'guillemets retires'     (Get-LienEditeur -Entree (EntreeReg @{ URLInfoAbout = '"https://a.example"' })) 'https://a.example'
ok 'espaces retires'        (Get-LienEditeur -Entree (EntreeReg @{ URLInfoAbout = '  https://a.example  ' })) 'https://a.example'
# Des installateurs mettent la un chemin local, un protocole exotique ou rien.
ok 'chemin local refuse'    (Get-LienEditeur -Entree (EntreeReg @{ URLInfoAbout = 'C:\Program Files\Truc' })) ''
ok 'file:// refuse'         (Get-LienEditeur -Entree (EntreeReg @{ URLInfoAbout = 'file:///C:/x.htm' })) ''
ok 'javascript: refuse'     (Get-LienEditeur -Entree (EntreeReg @{ URLInfoAbout = 'javascript:alert(1)' })) ''
ok 'vide refuse'            (Get-LienEditeur -Entree (EntreeReg @{ URLInfoAbout = '   ' })) ''
ok 'champ absent refuse'    (Get-LienEditeur -Entree (EntreeReg @{ Publisher = 'X' })) ''
ok 'entree nulle refusee'   (Get-LienEditeur -Entree $null) ''

$resultats = @{}
Add-App -Nom 'VLC' -Editeur 'VideoLAN' -Version '3' -Source 'registre' -Winget '' -Lien 'https://www.videolan.org/'
ok 'lien porte par l app'   $resultats[(Get-Cle -Nom 'VLC')].lien 'https://www.videolan.org/'
# Une deuxieme source sans lien ne doit pas effacer celui qu'on a.
Add-App -Nom 'VLC' -Editeur '' -Version '' -Source 'winget' -Winget 'VideoLAN.VLC'
ok 'lien conserve'          $resultats[(Get-Cle -Nom 'VLC')].lien 'https://www.videolan.org/'
# Et une source qui en apporte un le pose sur une ligne qui n'en avait pas.
Add-App -Nom 'Krita' -Editeur '' -Version '' -Source 'winget' -Winget ''
Add-App -Nom 'Krita' -Editeur 'KDE' -Version '' -Source 'registre' -Winget '' -Lien 'https://krita.org'
ok 'lien ajoute apres coup' $resultats[(Get-Cle -Nom 'Krita')].lien 'https://krita.org'

"--- la machine elle-meme ---"
$m = Format-Machine `
    -Systeme @((Obj @{ Manufacturer='Dell Inc.'; Model='XPS 15 9530' })) `
    -Bios    @((Obj @{ SerialNumber='7QK2X13' })) `
    -Chassis @((Obj @{ ChassisTypes=@(10) })) `
    -Ecrans  @((Obj @{ UserFriendlyName=@(68,101,108,108,0,0) }), (Obj @{ UserFriendlyName=@(76,71,0) }))
ok 'fabricant repris'        $m.fabricant 'Dell Inc.'
ok 'modele repris'           $m.modele 'XPS 15 9530'
ok 'numero de serie'         $m.serie '7QK2X13'
ok 'chassis portable'        $m.chassis 'portable'
ok 'deux ecrans'             $m.ecrans 2
ok 'le nom d ecran est decode' $m.modelesEcrans[0] 'Dell'
# Une machine assemblee ne remplit pas le SMBIOS : afficher « System Product
# Name » comme un modele ferait chercher un pilote qui n'existe pas.
$assemble = Format-Machine -Systeme @((Obj @{ Manufacturer='System manufacturer'; Model='System Product Name' })) `
    -Bios @((Obj @{ SerialNumber='To Be Filled By O.E.M.' })) -Chassis @((Obj @{ ChassisTypes=@(3) })) -Ecrans @()
ok 'le faux fabricant est ecarte' ($assemble.Contains('fabricant')) $false
ok 'le faux modele aussi'         ($assemble.Contains('modele')) $false
ok 'le faux numero aussi'         ($assemble.Contains('serie')) $false
ok 'mais le chassis fixe reste'   $assemble.chassis 'fixe'
ok 'tout vide ne jette pas'  (@((Format-Machine -Systeme $null -Bios $null -Chassis $null -Ecrans $null).Keys).Count) 0
ok 'machine declaree'        ($CouverturesScan.Contains('machine')) $true

"--- pilotes qui ne viennent pas de Microsoft ---"
$pil = @(Format-PilotesTiers -Pilotes @(
    (Obj @{ DriverProviderName='Microsoft'; DeviceClass='System'; DeviceName='Bus PCI' }),
    (Obj @{ DriverProviderName='Realtek'; DeviceClass='MEDIA'; DeviceName='Realtek Audio' }),
    (Obj @{ DriverProviderName='Realtek'; DeviceClass='MEDIA'; DeviceName='Realtek Audio 2' }),
    (Obj @{ DriverProviderName='NVIDIA'; DeviceClass='Display'; DeviceName='RTX 4070' }),
    (Obj @{ DriverProviderName='Brother'; DeviceClass='Printer'; DeviceName='Brother DCP' })))
ok 'Microsoft est ecarte'    (@($pil | Where-Object { $_.fournisseur -eq 'Microsoft' }).Count) 0
ok 'les imprimantes aussi'   (@($pil | Where-Object { $_.fournisseur -eq 'Brother' }).Count) 0
# Une carte mere declare vingt peripheriques du meme fournisseur : une ligne
# par couple fournisseur/classe suffit a savoir quoi chercher.
ok 'deux fournisseurs, pas quatre' (Get-Nombre $pil) 2
ok 'les appareils sont regroupes'  ($pil[0].appareils.Count) 2
ok 'liste vide'              (Get-Nombre (Format-PilotesTiers -Pilotes @())) 0

"--- date d installation ---"
ok 'une date normale'        (Format-DateInstallation -Brut '20240317') '2024-03-17'
ok 'une date absurde'        (Format-DateInstallation -Brut '20241345') ''
ok 'une annee impossible'    (Format-DateInstallation -Brut '18010101') ''
ok 'du texte'                (Format-DateInstallation -Brut 'mars 2024') ''
ok 'vide'                    (Format-DateInstallation -Brut '') ''


"--- ou le fichier de sortie atterrit ---"
# GetFullPath resout un chemin relatif contre Environment.CurrentDirectory,
# qui ne suit PAS Set-Location. « cd D:\cle » puis lancer le script ecrivait
# donc le fichier la ou PowerShell avait demarre, sans que rien ne le dise.
# Avec un nom fixe le defaut passait inapercu ; avec des instantanes dates il
# fait perdre le fichier qu'on vient de produire.
$bacCwd = Join-Path ([System.IO.Path]::GetTempPath()) ("cwd-" + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $bacCwd -Force
Push-Location $bacCwd
try {
    $r = Resolve-CheminSortie -Chemin 'instantane.json'
    ok 'un relatif suit le dossier courant' `
        ((Split-Path $r -Parent) -eq (Get-Location).ProviderPath) $true
    # Et pas celui du processus, qui est reste ailleurs.
    ok 'et pas celui du processus' `
        ((Split-Path $r -Parent) -eq [Environment]::CurrentDirectory) $false
} finally { Pop-Location }
$absolu = Join-Path ([System.IO.Path]::GetTempPath()) 'ailleurs.json'
ok 'un chemin absolu est respecte' (Resolve-CheminSortie -Chemin $absolu) ([System.IO.Path]::GetFullPath($absolu))
ok 'une chaine vide passe telle quelle' (Resolve-CheminSortie -Chemin '') ''
Remove-Item -LiteralPath $bacCwd -Recurse -Force -ErrorAction SilentlyContinue


if($script:ko){"`n$($script:ko) TEST(S) EN ECHEC"; exit 1} else {"`nTOUS LES TESTS POWERSHELL PASSENT"}
