# Tests de la detection partagee. Depuis que les trois scripts s'appuient sur
# lib-detection.ps1, il suffit de la charger : elle ne fait rien d'elle-meme.
#   pwsh -File tests/test-scan.ps1
$ToutInclure = $false
$resultats = @{}
$racineScan = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot/../scripts/lib-detection.ps1"
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

"--- ce qu il faut prevoir sur la cle ---"
# Le scan connaissait la taille de tout ce qu il propose d emporter et ne
# faisait jamais la somme. Decouvrir la cle pleine au milieu de la copie coute
# une soiree.
ok 'D:\Outils contient D:\Outils\ffmpeg' (Test-SousChemin -Parent 'D:\Outils' -Enfant 'D:\Outils\ffmpeg') $true
# Comparaison sur les segments, pas sur le texte, sinon « Outils2 » passerait
# pour un enfant de « Outils ».
ok 'mais pas D:\Outils2'          (Test-SousChemin -Parent 'D:\Outils' -Enfant 'D:\Outils2') $false
ok 'ni lui-meme'                   (Test-SousChemin -Parent 'D:\Outils' -Enfant 'D:\Outils') $false
ok 'la casse ne change rien'       (Test-SousChemin -Parent 'd:\outils' -Enfant 'D:\OUTILS\x') $true
ok 'une barre finale non plus'     (Test-SousChemin -Parent 'D:\Outils\' -Enfant 'D:\Outils\x') $true

# Un gros dossier signale contient parfois un portable ou une cle : les
# additionner gonflerait le chiffre.
$gros = @([ordered]@{ chemin = 'D:\Outils'; tailleMo = 100 })
$port = @([ordered]@{ chemin = 'D:\Outils\ffmpeg'; tailleMo = 40 },
          [ordered]@{ chemin = 'E:\Ailleurs'; tailleMo = 7 })
$cles = @([ordered]@{ chemin = 'D:\Outils\a.jks'; tailleKo = 2048 })
ok 'rien n est compte deux fois'   (Get-TotalAPrevoirMo @($gros, $port, $cles)) 107
# Les kilo-octets d une cle comptent aussi, une fois convertis.
ok 'une cle isolee compte'         (Get-TotalAPrevoirMo @(@([ordered]@{ chemin = 'X:\a.jks'; tailleKo = 2048 }))) 2
ok 'sans rien, zero'               (Get-TotalAPrevoirMo @()) 0
ok 'une entree sans taille vaut 0' (Get-TotalAPrevoirMo @(@([ordered]@{ chemin = 'X:\a' }))) 0

"--- les logiciels portables, qu aucune source ne voit ---"
# Un .exe dezippe dans un dossier n a aucune entree de desinstallation, aucun
# identifiant winget, rien dans le Store. Ce releve est une liste de suspects,
# pas un inventaire : tout l enjeu est de limiter le bruit.
$bacP = Join-Path ([System.IO.Path]::GetTempPath()) ("mpc-port-" + (Get-Random))
try {
    foreach ($d in @('Outils\ffmpeg', 'Outils\sumatrapdf', 'Jeux\node_modules\x',
                     'Collection', 'Telechargements\truc-setup', 'Projets\build',
                     'Outils\7-Zip')) {
        New-Item -ItemType Directory -Path (Join-Path $bacP $d) -Force | Out-Null
    }
    Set-Content -LiteralPath (Join-Path $bacP 'Outils\ffmpeg\ffmpeg.exe') -Value 'x'
    Set-Content -LiteralPath (Join-Path $bacP 'Outils\sumatrapdf\SumatraPDF.exe') -Value 'x'
    # Un installateur accompagne le logiciel sans etre le logiciel.
    Set-Content -LiteralPath (Join-Path $bacP 'Outils\sumatrapdf\uninstall.exe') -Value 'x'
    Set-Content -LiteralPath (Join-Path $bacP 'Jeux\node_modules\x\bidule.exe') -Value 'x'
    Set-Content -LiteralPath (Join-Path $bacP 'Telechargements\truc-setup\setup.exe') -Value 'x'
    Set-Content -LiteralPath (Join-Path $bacP 'Projets\build\monprog.exe') -Value 'x'
    Set-Content -LiteralPath (Join-Path $bacP 'Outils\7-Zip\7zFM.exe') -Value 'x'
    # Beaucoup d executables au meme endroit : une collection, pas une application.
    1..6 | ForEach-Object { Set-Content -LiteralPath (Join-Path $bacP "Collection\app$_.exe") -Value 'x' }

    $pt = @(Format-Portables -Racine $bacP -Modele '%USERPROFILE%')
    $noms = @($pt | ForEach-Object { $_.nom })
    ok 'les trois candidats sont vus' $pt.Count 3
    ok 'ffmpeg en fait partie'        ($noms -contains 'ffmpeg') $true
    ok 'SumatraPDF aussi'             ($noms -contains 'sumatrapdf') $true
    ok 'et 7-Zip, faute de savoir'    ($noms -contains '7-Zip') $true
    # Ce qui doit rester dehors, sinon la liste devient illisible.
    ok 'une collection est ecartee'   ($noms -contains 'Collection') $false
    ok 'node_modules aussi'           ($noms -contains 'x') $false
    ok 'un dossier de build aussi'    ($noms -contains 'build') $false
    ok 'un dossier d installateur aussi' ($noms -contains 'truc-setup') $false
    # L installateur qui accompagne le logiciel ne doit pas empecher de le voir.
    $sum = @($pt | Where-Object { $_.nom -eq 'sumatrapdf' })[0]
    ok 'l installateur n est pas compte' ($sum.exes -contains 'uninstall.exe') $false
    ok 'mais le logiciel si'          ($sum.exes -contains 'SumatraPDF.exe') $true
    ok 'le modele est variabilise'    (@($pt | Where-Object { $_.nom -eq 'ffmpeg' })[0].modele) '%USERPROFILE%\Outils\ffmpeg'

    # Deja vu par le registre : le reproposer sous un autre nom serait doubler.
    # Deja vu par le registre : le reproposer serait doubler. C est ce qui fait
    # passer 7-Zip de « candidat » a « deja connu », sans toucher aux autres.
    $pt2 = @(Format-Portables -Racine $bacP -ClesInstallees @((Get-Cle -Nom '7-Zip')))
    $noms2 = @($pt2 | ForEach-Object { $_.nom })
    ok 'un logiciel deja installe est ecarte' ($noms2 -contains '7-Zip') $false
    ok 'et les autres restent'        $pt2.Count 2

    ok 'une racine absente ne rend rien' (@(Format-Portables -Racine (Join-Path $bacP 'nexistepas')).Count) 0
    ok 'un budget nul arrete tout'    (@(Format-Portables -Racine $bacP -BudgetSecondes 0).Count) 0
} finally {
    Remove-Item $bacP -Recurse -Force -ErrorAction SilentlyContinue
}

"--- les cles de signature, qui ne se recreent pas ---"
# Un keystore de release perdu oblige a passer par la procedure de
# reinitialisation de cle chez l editeur. Il pese quelques kilo-octets et vit
# la ou son proprietaire l a mis : on ne peut pas deviner, on peut chercher.
$bacK = Join-Path ([System.IO.Path]::GetTempPath()) ("mpc-cles-" + (Get-Random))
try {
    foreach ($d in @('MonProjet', 'node_modules\truc', 'AppData\Local', '.gradle\caches')) {
        New-Item -ItemType Directory -Path (Join-Path $bacK $d) -Force | Out-Null
    }
    Set-Content -LiteralPath (Join-Path $bacK 'MonProjet\release.jks') -Value 'x'
    Set-Content -LiteralPath (Join-Path $bacK 'MonProjet\upload.keystore') -Value 'x'
    Set-Content -LiteralPath (Join-Path $bacK 'MonProjet\lisez-moi.txt') -Value 'x'
    # Du bruit : des keystores d echafaudage que personne ne cherche a sauver.
    Set-Content -LiteralPath (Join-Path $bacK 'node_modules\truc\test.jks') -Value 'x'
    Set-Content -LiteralPath (Join-Path $bacK 'AppData\Local\cache.keystore') -Value 'x'
    Set-Content -LiteralPath (Join-Path $bacK '.gradle\caches\vieux.jks') -Value 'x'

    $k = @(Find-FichiersPrecieux -Racine $bacK -Modele '%USERPROFILE%')
    $noms = @($k | ForEach-Object { $_.nom })
    ok 'les deux cles du projet sont vues' $k.Count 2
    ok 'un .jks'                      ($noms -contains 'release.jks') $true
    ok 'un .keystore'                 ($noms -contains 'upload.keystore') $true
    # -Include combine a -LiteralPath est ignore par Windows PowerShell 5.1,
    # qui rend alors TOUS les fichiers : la recherche de cles aurait rapporte
    # le disque entier. Le filtre se fait donc a la main.
    ok 'pas les autres fichiers'      ($noms -contains 'lisez-moi.txt') $false
    ok 'ni un fichier sans extension' ($noms -contains 'sans-extension') $false
    # Signaler ceux-la noierait les vrais.
    ok 'node_modules est ecarte'      ($noms -contains 'test.jks') $false
    ok 'AppData aussi'                ($noms -contains 'cache.keystore') $false
    ok 'les caches Gradle aussi'      ($noms -contains 'vieux.jks') $false
    # Le modele decrit un chemin Windows : deux separateurs melanges ne se
    # reliraient nulle part.
    $m = @($k | Where-Object { $_.nom -eq 'release.jks' })[0].modele
    ok 'le modele est variabilise'    $m '%USERPROFILE%\MonProjet\release.jks'
    ok 'sans separateur etranger'     ($m -like '*/*') $false
    ok 'une racine absente ne rend rien' (@(Find-FichiersPrecieux -Racine (Join-Path $bacK 'nexistepas')).Count) 0
} finally {
    Remove-Item $bacK -Recurse -Force -ErrorAction SilentlyContinue
}

"--- les extensions, qu on ne reinstalle pas a la main ---"
$bacX = Join-Path ([System.IO.Path]::GetTempPath()) ("mpc-ext-" + (Get-Random))
try {
    foreach ($d in @('vsc\dbaeumer.vscode-eslint-3.0.10', 'vsc\ms-python.python-2024.14.0',
                     'vsc\pas-un-identifiant',
                     'chrome\cjpalhdlnbpafiamejdnhcphjbkeiagm\1.60.0',
                     'chrome\abcdefghijklmnopabcdefghijklmnop\2.0',
                     'chrome\PASUNIDENTIFIANT\1.0')) {
        New-Item -ItemType Directory -Path (Join-Path $bacX $d) -Force | Out-Null
    }
    # VS Code : le nom du dossier dit tout, pas besoin de lancer `code`.
    $vs = @(Format-ExtensionsVsCode -Racine (Join-Path $bacX 'vsc'))
    ok 'deux extensions VS Code'      $vs.Count 2
    ok 'la version est separee'       (@($vs | Where-Object { $_.id -eq 'ms-python.python' })[0].version) '2024.14.0'
    # L identifiant doit etre celui que `code --install-extension` reprend.
    ok 'la commande est utilisable'   (@($vs | Where-Object { $_.id -eq 'ms-python.python' })[0].commande) 'code --install-extension ms-python.python'

    Set-Content -LiteralPath (Join-Path $bacX 'chrome\cjpalhdlnbpafiamejdnhcphjbkeiagm\1.60.0\manifest.json') `
        -Value '{"name":"uBlock Origin","version":"1.60.0"}'
    # Le nom lisible est souvent une reference de traduction : afficher
    # « __MSG_appName__ » a quelqu un ne l aide pas.
    Set-Content -LiteralPath (Join-Path $bacX 'chrome\abcdefghijklmnopabcdefghijklmnop\2.0\manifest.json') `
        -Value '{"name":"__MSG_appName__"}'
    $ch = @(Format-ExtensionsChromium -Racine (Join-Path $bacX 'chrome') -Navigateur 'Chrome')
    ok 'deux extensions Chromium'     $ch.Count 2
    ok 'un dossier qui n est pas un identifiant est ignore' `
        (@($ch | Where-Object { $_.id -eq 'PASUNIDENTIFIANT' }).Count) 0
    ok 'le nom lisible est repris'    (@($ch | Where-Object { $_.id -like 'cjpal*' })[0].nom) 'uBlock Origin'
    ok 'une reference de traduction ne s affiche pas' `
        (@($ch | Where-Object { $_.id -like 'abcdef*' })[0].nom) 'abcdefghijklmnopabcdefghijklmnop'

    # Firefox tient un extensions.json par profil, ou les noms sont lisibles.
    $j = '{"addons":[' +
         '{"id":"ublock@raymondhill.net","location":"app-profile","version":"1.60","defaultLocale":{"name":"uBlock Origin"}},' +
         '{"id":"livre@mozilla.org","location":"app-builtin"},' +
         '{"location":"app-profile"}]}'
    $ff = @(Format-ExtensionsFirefox -Json $j)
    ok 'une extension Firefox'        $ff.Count 1
    ok 'avec son nom lisible'         $ff[0].nom 'uBlock Origin'
    # Un greffon livre avec Firefox ne se reinstalle pas : le proposer serait faux.
    ok 'les greffons livres sont ecartes' (@($ff | Where-Object { $_.id -like '*mozilla.org' }).Count) 0
    ok 'du JSON casse ne casse rien'  (@(Format-ExtensionsFirefox -Json 'pas du json').Count) 0
    ok 'un dossier absent non plus'   (@(Format-ExtensionsVsCode -Racine (Join-Path $bacX 'nexistepas')).Count) 0
} finally {
    Remove-Item $bacX -Recurse -Force -ErrorAction SilentlyContinue
}

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

"--- les gros dossiers qu on oublie ---"
# Le projet ne detectait aucun fichier personnel. Un logiciel oublie se
# reinstalle ; un dossier de photos oublie ne revient pas.
$bacG = Join-Path ([System.IO.Path]::GetTempPath()) ("mpc-gros-" + (Get-Random))
foreach ($d in @('Projets\sous', 'Photos', 'Petit', 'Windows', 'AppData')) {
    New-Item -ItemType Directory -Path (Join-Path $bacG $d) -Force | Out-Null
}
try {
    Set-Content -LiteralPath (Join-Path $bacG 'Projets\sous\a.bin') -Value ('x' * 3MB) -NoNewline
    Set-Content -LiteralPath (Join-Path $bacG 'Photos\b.bin')        -Value ('x' * 2MB) -NoNewline
    Set-Content -LiteralPath (Join-Path $bacG 'Petit\c.bin')         -Value 'rien'
    Set-Content -LiteralPath (Join-Path $bacG 'Windows\gros.bin')    -Value ('x' * 9MB) -NoNewline
    Set-Content -LiteralPath (Join-Path $bacG 'AppData\gros.bin')    -Value ('x' * 9MB) -NoNewline

    $g = @(Measure-DossiersEnfants -Racine $bacG -SeuilMo 1 -Modele '%USERPROFILE%')
    $noms = @($g | ForEach-Object { $_.nom })
    ok 'les gros dossiers sont vus'   ($noms -contains 'Projets') $true
    ok 'la taille compte le sous-dossier' ([math]::Round(@($g | Where-Object { $_.nom -eq 'Projets' })[0].tailleMo, 0)) 3
    ok 'les petits sont laisses'      ($noms -contains 'Petit') $false
    # Windows et AppData sont geres par Windows : les signaler noierait le reste.
    ok 'Windows est ecarte'           ($noms -contains 'Windows') $false
    ok 'AppData aussi'                ($noms -contains 'AppData') $false
    # Le modele permettra de retrouver le dossier sous un autre nom
    # d utilisateur, comme pour les configurations.
    ok 'le modele est variabilise'    (@($g | Where-Object { $_.nom -eq 'Photos' })[0].modele) '%USERPROFILE%\Photos'
    ok 'une racine de disque n en a pas' `
        (@(Measure-DossiersEnfants -Racine $bacG -SeuilMo 1)[0].modele) ''

    # Un disque de plusieurs teraoctets ne se parcourt pas pendant qu on attend
    # devant l ecran : mieux vaut une mesure partielle annoncee comme telle.
    $court = @(Measure-DossiersEnfants -Racine $bacG -SeuilMo 0.0001 -BudgetSecondes 0)
    ok 'le budget arrete le parcours' $court.Count 1
    ok 'et la mesure se dit partielle' $court[0].complet $false

    ok 'une racine absente ne rend rien' (@(Measure-DossiersEnfants -Racine (Join-Path $bacG 'nexistepas')).Count) 0
} finally {
    Remove-Item $bacG -Recurse -Force -ErrorAction SilentlyContinue
}

"--- les chaines d outils que rien n enregistre ---"
# Ni le registre, ni winget, ni le Store ne savent quoi que ce soit du SDK
# Android, de WSL, de scoop ou des paquets globaux de npm. On ne les copie pas,
# on emporte la liste et la commande qui remet chacun en place.
$bacO = Join-Path ([System.IO.Path]::GetTempPath()) ("mpc-outils-" + (Get-Random))
foreach ($d in @('platforms\android-34', 'platforms\android-35', 'build-tools\34.0.0',
                 'ndk\26.1.10909125', 'platform-tools', 'emulator',
                 'system-images\android-34\google_apis\x86_64')) {
    New-Item -ItemType Directory -Path (Join-Path $bacO "sdk\$d") -Force | Out-Null
}
try {
    $sdk = @(Format-PaquetsSdk -Racine (Join-Path $bacO 'sdk'))
    $ids = @($sdk | ForEach-Object { $_.id })
    ok 'une plateforme est vue'      ($ids -contains 'platforms;android-34') $true
    ok 'les build-tools aussi'       ($ids -contains 'build-tools;34.0.0') $true
    ok 'le NDK aussi'                ($ids -contains 'ndk;26.1.10909125') $true
    ok 'platform-tools, sans version' ($ids -contains 'platform-tools') $true
    # Les images systeme ont trois niveaux : un identifiant tronque ne
    # reinstallerait pas la bonne image.
    ok 'une image systeme complete'  ($ids -contains 'system-images;android-34;google_apis;x86_64') $true
    # L identifiant doit etre celui que sdkmanager reprend tel quel.
    $p34 = @($sdk | Where-Object { $_.id -eq 'platforms;android-34' })[0]
    ok 'la commande est utilisable'  $p34.commande 'sdkmanager "platforms;android-34"'
    ok 'un SDK absent ne rend rien'  (@(Format-PaquetsSdk -Racine (Join-Path $bacO 'nexistepas')).Count) 0
    ok 'une racine vide non plus'    (@(Format-PaquetsSdk -Racine '').Count) 0

    # wsl.exe ecrit en UTF-16 : lu naivement, chaque nom arrive espace de
    # caracteres nuls. Le piege coute une heure a qui l ignore.
    $brut = @("`0W`0i`0n`0d`0o`0w`0s`0 `0S`0u`0b`0s`0y`0s`0t`0e`0m", '* Ubuntu-22.04', 'Debian', '', 'docker-desktop')
    $wsl = @(Format-DistributionsWsl -Lignes $brut)
    ok 'trois distributions'         $wsl.Count 3
    ok 'les nuls sont retires'       ($wsl[0].id) 'Ubuntu-22.04'
    ok 'la par defaut est signalee'  ($wsl[0].nom) 'Ubuntu-22.04 (par defaut)'
    ok 'et la commande est juste'    ($wsl[0].commande) 'wsl --install -d Ubuntu-22.04'
    ok 'l en-tete n est pas une distribution' (@($wsl | Where-Object { $_.id -like '*Subsystem*' }).Count) 0

    New-Item -ItemType Directory -Path (Join-Path $bacO 'scoop\apps\7zip') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $bacO 'scoop\apps\scoop') -Force | Out-Null
    $sc = @(Format-PaquetsDossier -Racine (Join-Path $bacO 'scoop\apps') -Famille 'scoop' -Modele 'scoop install {0}')
    ok 'un paquet scoop est vu'      $sc.Count 1
    ok 'scoop lui-meme est ignore'   (@($sc | Where-Object { $_.id -eq 'scoop' }).Count) 0

    # npm et corepack sont livres avec Node : les voir dans la liste ferait
    # douter du reste.
    $npm = @(Format-PaquetsNpm -Json '{"dependencies":{"typescript":{"version":"5.6.2"},"npm":{"version":"10.9.0"},"corepack":{"version":"0.34"}}}')
    ok 'un paquet global est vu'     $npm.Count 1
    ok 'avec sa version'             $npm[0].version '5.6.2'
    ok 'du JSON illisible ne casse rien' (@(Format-PaquetsNpm -Json 'pas du json').Count) 0
    ok 'rien du tout non plus'       (@(Format-PaquetsNpm -Json '').Count) 0

    $pip = @(Format-PaquetsPip -Lignes @('requests==2.32.3', '', 'ruff==0.6.8', 'ligne invalide'))
    ok 'deux paquets pip'            $pip.Count 2
    ok 'la version est separee'      $pip[0].version '2.32.3'
} finally {
    Remove-Item $bacO -Recurse -Force -ErrorAction SilentlyContinue
}

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

"--- licences ---"
function Licence($h){ $o = New-Object PSObject; foreach($k in $h.Keys){ $o | Add-Member -NotePropertyName $k -NotePropertyValue $h[$k] }; return $o }
$lic = @(Format-Licences -Produits @(
    (Licence @{ Name='Windows(R), Professional edition'; PartialProductKey='7X2QK'; ProductKeyChannel='OEM';    LicenseStatus=1 }),
    (Licence @{ Name='Office 16, Office16ProPlus';       PartialProductKey='9BQRT'; ProductKeyChannel='Retail'; LicenseStatus=1 }),
    (Licence @{ Name='Windows(R), Core edition';         PartialProductKey='';      ProductKeyChannel='OEM';    LicenseStatus=1 })
))
# La troisieme n'a pas de cle partielle : produit installable mais pas licencie.
ok 'sans cle partielle ecartee' (Get-Nombre $lic) 2
ok 'canal OEM lu'           $lic[0].canal 'OEM'
ok 'OEM ne suit pas'         $lic[0].suitLeMateriel $false
ok 'Retail suit'             $lic[1].suitLeMateriel $true
ok 'etat traduit'            $lic[0].etat 'active'
ok 'cle partielle gardee'    $lic[0].clePartielle '7X2QK'
ok 'explication non vide'    ($lic[0].quoi.Length -gt 20) $true
# Un canal que Windows peut rendre et qu'on ne connait pas ne doit rien affirmer.
$inc = @(Format-Licences -Produits @((Licence @{ Name='X'; PartialProductKey='AAAAA'; ProductKeyChannel='CanalInedit'; LicenseStatus=1 })))
ok 'canal inconnu sans verdict' ($null -eq $inc[0].suitLeMateriel) $true
ok 'canal inconnu explique'     ($inc[0].quoi -like '*verifie*') $true
# Champs manquants : StrictMode ne doit pas faire tomber le scan.
$vide = @(Format-Licences -Produits @((Licence @{ Name='Y'; PartialProductKey='BBBBB' })))
ok 'sans canal ni etat'      (Get-Nombre $vide) 1
ok 'canal vide'              $vide[0].canal ''
ok 'liste vide sans erreur'  (Get-Nombre (Format-Licences -Produits @())) 0
ok 'null sans erreur'        (Get-Nombre (Format-Licences -Produits $null)) 0
ok 'licences declarees'      ($CouverturesScan.Contains('licences')) $true

"--- controles de la machine neuve ---"
function Obj($h){ $o = New-Object PSObject; foreach($k in $h.Keys){ $o | Add-Member -NotePropertyName $k -NotePropertyValue $h[$k] }; return $o }

# 1. XMP : l'erreur d'assemblage la plus repandue, et la plus silencieuse.
$lente = Format-ControleMemoire -Barrettes @((Obj @{ Speed=6000; ConfiguredClockSpeed=4800 }))
ok 'XMP non active detecte'  $lente.etat 'attention'
ok 'les deux chiffres sont dits' ($lente.constat -like '*4800*' -and $lente.constat -like '*6000*') $true
ok 'XMP nomme dans le remede' ($lente.quoi -like '*XMP*') $true
$bonne = Format-ControleMemoire -Barrettes @((Obj @{ Speed=6000; ConfiguredClockSpeed=6000 }))
ok 'memoire a sa vitesse'    $bonne.etat 'ok'
# Une barrette plus lente que l'autre ne doit pas masquer la plus rapide.
$mix = Format-ControleMemoire -Barrettes @((Obj @{ Speed=6000; ConfiguredClockSpeed=6000 }), (Obj @{ Speed=6000; ConfiguredClockSpeed=6000 }))
ok 'deux barrettes conformes' $mix.etat 'ok'
ok 'sans barrette, inconnu'  (Format-ControleMemoire -Barrettes @()).etat 'inconnu'
ok 'sans vitesse, inconnu'   (Format-ControleMemoire -Barrettes @((Obj @{ Capacity=8 }))).etat 'inconnu'

# 2. TRIM.
ok 'TRIM absent = actif'     (Format-ControleTrim -Valeur $null).etat 'ok'
ok 'TRIM a 0 = actif'        (Format-ControleTrim -Valeur 0).etat 'ok'
ok 'TRIM a 1 = coupe'        (Format-ControleTrim -Valeur 1).etat 'attention'
ok 'la commande est donnee'  ((Format-ControleTrim -Valeur 1).quoi -like '*fsutil*') $true
ok 'valeur illisible'        (Format-ControleTrim -Valeur 'oui').etat 'inconnu'

# 3. Secure Boot et TPM.
$tpmOn  = Obj @{ IsEnabled_InitialValue=$true; SpecVersion='2.0, 0, 1.38' }
$tpmOff = Obj @{ IsEnabled_InitialValue=$false; SpecVersion='2.0, 0, 1.38' }
$bon = Format-ControleDemarrage -SecureBoot $true -Tpm $tpmOn
ok 'Secure Boot + TPM ok'    $bon.etat 'ok'
ok 'la version du TPM est dite' ($bon.constat -like '*2.0*') $true
ok 'Secure Boot coupe'       (Format-ControleDemarrage -SecureBoot $false -Tpm $tpmOn).etat 'attention'
ok 'TPM coupe'               (Format-ControleDemarrage -SecureBoot $true -Tpm $tpmOff).etat 'attention'
# Sans les droits administrateur, les deux remontent $null : on dit « je ne
# sais pas », jamais « tout va bien ».
$ind = Format-ControleDemarrage -SecureBoot $null -Tpm $null
ok 'indetermine, pas ok'     $ind.etat 'inconnu'
ok 'et on dit quoi faire'    ($ind.quoi -like '*administrateur*') $true

# 4. Le disque a-t-il deja servi ?
$neuf  = Format-ControleDisques -Compteurs @((Obj @{ PowerOnHours=3;   DeviceId='Samsung 990' }))
$use   = Format-ControleDisques -Compteurs @((Obj @{ PowerOnHours=412; DeviceId='Samsung 990' }))
ok 'disque neuf'             $neuf.etat 'ok'
ok 'disque deja servi'       $use.etat 'attention'
ok 'le compteur est cite'    ($use.constat -like '*412*') $true
ok 'le disque est nomme'     ($use.constat -like '*Samsung 990*') $true
ok 'seuil reglable'          (Format-ControleDisques -Compteurs @((Obj @{ PowerOnHours=412; DeviceId='X' })) -SeuilHeures 500).etat 'ok'
ok 'aucun compteur, inconnu' (Format-ControleDisques -Compteurs @()).etat 'inconnu'
ok 'compteur absent, inconnu' (Format-ControleDisques -Compteurs @((Obj @{ DeviceId='X' }))).etat 'inconnu'
ok 'controles declares'      ($CouverturesScan.Contains('controles')) $true

"--- les reglages qui vivent dans le registre ---"
# PuTTY ne pose aucun fichier : ses sessions SSH entieres sont dans
# HKCU\Software\SimonTatham. La table ne connaissait que des chemins, donc
# elles partaient en silence — rien n'echouait, elles n'etaient jamais vues.
$avecReg = @($ConfigsConnues | Where-Object { $_.Contains('registre') -and $_.registre })
ok 'des regles designent le registre' ($avecReg.Count -ge 5) $true
ok 'PuTTY en fait partie' (@($avecReg | Where-Object { $_.nom -like '*PuTTY*' }).Count) 1
ok 'et il n a aucun fichier'  (@(@($ConfigsConnues | Where-Object { $_.nom -like '*PuTTY*' })[0].chemins).Count) 0
# Une cle mal ecrite ne se verrait qu'au moment de l'export, sur Windows.
$malEcrites = @($avecReg | ForEach-Object { $_.registre } |
    Where-Object { $_ -notmatch '^HK(CU|LM|CR|U|CC):\\' })
ok 'toutes les cles sont des chemins PowerShell' ($malEcrites -join ', ') ''
# Hors de Windows, le lecteur HKCU: n'existe pas : la lecture doit rendre
# $false sans jeter, sinon le scan tomberait sur une machine de test.
ok 'une cle absente ne jette pas' (Test-CleRegistre -Cle 'HKCU:\Software\NExistePas7734') $false
ok 'une cle vide non plus'        (Test-CleRegistre -Cle '') $false
ok 'un null non plus'             (Test-CleRegistre -Cle $null) $false

"--- prevenir avant de copier, pas apres ---"
# Firefox ouvert verrouille places.sqlite, cookies.sqlite et key4.db : les
# marque-pages et les mots de passe, exactement ce qu'on vient chercher.
function Proc($n){ return [pscustomobject]@{ ProcessName = $n } }
$ouverts = @(Get-LogicielsAFermer -NomsConfigs @('Profils Firefox','Thunderbird') `
    -Processus @((Proc 'firefox'), (Proc 'bash'), (Proc 'thunderbird')))
ok 'Firefox signale'         ($ouverts -contains 'Profils Firefox') $true
ok 'Thunderbird aussi'       ($ouverts -contains 'Thunderbird') $true
ok 'et rien d autre'         (Get-Nombre $ouverts) 2
# On ne previent que de ce qui est vraiment dans la copie : un Chrome ouvert
# n'a pas a inquieter quelqu'un qui n'emporte que ses cles SSH.
$horsCopie = @(Get-LogicielsAFermer -NomsConfigs @('Clés SSH') -Processus @((Proc 'chrome')))
ok 'un logiciel hors copie se tait' (Get-Nombre $horsCopie) 0
# Deux fenetres du meme navigateur ne doivent pas donner deux lignes.
$deuxFois = @(Get-LogicielsAFermer -NomsConfigs @('Profils Firefox') `
    -Processus @((Proc 'firefox'), (Proc 'firefox')))
ok 'un seul avertissement par logiciel' (Get-Nombre $deuxFois) 1
ok 'aucun processus, aucun avertissement' (Get-Nombre (Get-LogicielsAFermer -NomsConfigs @('Profils Firefox') -Processus @())) 0
# Sans liste de configs, on previent de tout ce qui est ouvert : c'est le cas
# ou le script ne sait pas encore ce qu'il va copier.
ok 'sans filtre, tout remonte' (Get-Nombre (Get-LogicielsAFermer -Processus @((Proc 'chrome')))) 1


"--- logiciels sous licence ---"
# Ce qu'on affirme ici est modeste : une liste tenue a la main. Le test verifie
# surtout qu'elle ne deborde pas — un faux « prevois une licence » sur un
# logiciel gratuit ferait chercher une cle qui n'existe pas.
ok 'Office marque payant'    ([bool](Get-LicenceAPrevoir -Nom 'Microsoft 365 Apps for enterprise')) $true
ok 'et explique quoi faire'  ((Get-LicenceAPrevoir -Nom 'Microsoft Office Professional Plus 2021') -like '*compte Microsoft*') $true
ok 'WinRAR marque payant'    ((Get-LicenceAPrevoir -Nom 'WinRAR 6.24 (64-bit)') -like '*rarreg.key*') $true
ok 'Photoshop marque payant' ([bool](Get-LicenceAPrevoir -Nom 'Adobe Photoshop 2024')) $true
ok 'un antivirus payant'     ([bool](Get-LicenceAPrevoir -Nom 'Bitdefender Total Security')) $true
# Le piege : « Microsoft » ne suffit pas. Un poste Windows porte une dizaine de
# Visual C++ Redistributable, aucun ne reclame de cle.
ok 'Visual C++ reste gratuit' (Get-LicenceAPrevoir -Nom 'Microsoft Visual C++ 2015-2022 Redistributable (x64)') ''
ok 'Edge reste gratuit'       (Get-LicenceAPrevoir -Nom 'Microsoft Edge' -Editeur 'Microsoft Corporation') ''
ok '7-Zip reste gratuit'      (Get-LicenceAPrevoir -Nom '7-Zip 23.01') ''
ok 'Firefox reste gratuit'    (Get-LicenceAPrevoir -Nom 'Mozilla Firefox' -Editeur 'Mozilla') ''
ok 'VLC reste gratuit'        (Get-LicenceAPrevoir -Nom 'VLC media player') ''
ok 'PyCharm Community gratuit' (Get-LicenceAPrevoir -Nom 'PyCharm Community Edition 2024.1') ''
ok 'un nom vide ne dit rien'  (Get-LicenceAPrevoir -Nom '') ''
# Vide veut dire « je ne sais pas », jamais « gratuit » : c'est la page qui le
# formule, mais la liste doit rester courte et sure pour que ce soit vrai.
ok 'la liste reste explicite' ($LogicielsPayants.Count -ge 10) $true
ok 'chaque regle explique'    (@($LogicielsPayants | Where-Object { -not $_.quoi }).Count) 0
ok 'payants declares'         ($CouverturesScan.Contains('payants')) $true

# Les fichiers de licence : on releve le chemin, jamais le contenu.
ok 'des fichiers connus'      ($FichiersLicence.Count -ge 5) $true
ok 'rarreg.key en fait partie' ([bool](@($FichiersLicence | Where-Object { $_.nom -eq 'WinRAR' }).Count)) $true
$champsLicence = @($FichiersLicence | Where-Object { -not $_.nom -or -not $_.chemins })
ok 'chaque fichier a nom et chemins' (Get-Nombre $champsLicence) 0
# Aucune regle ne doit lire le fichier : le mot « Get-Content » ne doit pas
# apparaitre dans le detecteur, sinon la cle finirait dans l'inventaire.
$srcLic = (Get-Content -Raw -Encoding UTF8 (Join-Path $racineScan 'scripts/lib-detection.ps1'))
$blocLic = ($srcLic -split 'function Read-FichiersLicence')[1]
$blocLic = ($blocLic -split '# ---')[0]
ok 'le detecteur ne lit pas le contenu' ($blocLic -notmatch 'Get-Content') $true
ok 'et marque le secret'                ($blocLic -match 'secret\s*=\s*\$true') $true


"--- VPN ---"
# Ce qui sort d'une connexion Windows : le nom, le serveur, le type. Jamais le
# mot de passe, et le test le verifie sur la sortie entiere.
$vpns = @(Format-Vpn -Connexions @(
    (Obj @{ Name='Bureau'; ServerAddress='vpn.exemple.fr'; TunnelType='Ikev2' }),
    (Obj @{ Name='Maison'; ServerAddress='10.0.0.1'; TunnelType='L2tp' })))
ok 'deux connexions'         (Get-Nombre $vpns) 2
ok 'le serveur est repris'   $vpns[0].serveur 'vpn.exemple.fr'
ok 'le type est lisible'     $vpns[0].type 'IKEv2'
ok 'L2TP aussi'              $vpns[1].type 'L2TP/IPsec'
ok 'et rien de secret'       $vpns[0].secret $false
ok 'la ligne le dit'         ($vpns[0].quoi -like '*mot de passe*') $true
# StrictMode : une connexion sans type ne doit pas faire tomber le scan.
$partiel = @(Format-Vpn -Connexions @((Obj @{ Name='Minimal' })))
ok 'sans serveur ni type'    (Get-Nombre $partiel) 1
ok 'type vide'               $partiel[0].type ''
ok 'sans nom, rien'          (Get-Nombre (Format-Vpn -Connexions @((Obj @{ ServerAddress='x' })))) 0
ok 'liste vide'              (Get-Nombre (Format-Vpn -Connexions @())) 0
ok 'null'                    (Get-Nombre (Format-Vpn -Connexions $null)) 0
# Les VPN par abonnement n'ont pas de fichier : la ligne doit le dire au lieu
# d'envoyer chercher une configuration qui n'existe pas.
$abo = @(Get-VpnAbonnement -ClesInstallees @('nordvpn', 'mozillafirefox', 'tailscale'))
ok 'deux abonnements reperes' (Get-Nombre $abo) 2
ok 'rien a copier'            ($abo[0].quoi -like '*dans le compte*') $true
ok 'un logiciel quelconque ne compte pas' (Get-Nombre (Get-VpnAbonnement -ClesInstallees @('7zip'))) 0
ok 'vpn declare'              ($CouverturesScan.Contains('vpn')) $true

"--- favoris ---"
$jsonFav = '{"roots":{"bookmark_bar":{"type":"folder","children":[' +
  '{"type":"url","url":"https://a.example"},' +
  '{"type":"folder","children":[{"type":"url","url":"https://b.example"},{"type":"url","url":"https://c.example"}]}' +
  ']},"other":{"type":"folder","children":[{"type":"url","url":"https://d.example"}]}}}'
ok 'quatre favoris comptes'  (Measure-FavorisChromium -Json $jsonFav) 4
ok 'les dossiers ne comptent pas' (Measure-FavorisChromium -Json '{"roots":{"bookmark_bar":{"type":"folder","children":[]}}}') 0
ok 'un JSON casse ne jette pas'   (Measure-FavorisChromium -Json '{pas du json') $null
ok 'un JSON sans roots'           (Measure-FavorisChromium -Json '{"autre":1}') $null
ok 'une chaine vide'              (Measure-FavorisChromium -Json '') $null
ok 'favoris declares'             ($CouverturesScan.Contains('favoris')) $true

"--- machines virtuelles ---"
$xmlVbox = '<?xml version="1.0"?><VirtualBox><Global><MachineRegistry>' +
  '<MachineEntry uuid="{1}" src="C:\VMs\Debian\Debian.vbox"/>' +
  '<MachineEntry uuid="{2}" src="C:\VMs\Windows 11\Windows 11.vbox"/>' +
  '</MachineRegistry></Global></VirtualBox>'
$vbox = @(Format-VmVirtualBox -Xml $xmlVbox)
ok 'deux machines VirtualBox' (Get-Nombre $vbox) 2
ok 'le nom vient du dossier'  $vbox[0].nom 'Debian'
ok 'le chemin est le dossier' $vbox[0].chemin 'C:\VMs\Debian'
ok 'un espace dans le nom'    $vbox[1].nom 'Windows 11'
ok 'un XML casse ne jette pas' (Get-Nombre (Format-VmVirtualBox -Xml '<pas')) 0
ok 'un XML vide non plus'      (Get-Nombre (Format-VmVirtualBox -Xml '')) 0

$vmls = "vmlist1.config = `"C:\VMs\Ubuntu\Ubuntu.vmx`"`r`nvmlist1.DisplayName = `"Ubuntu`"`r`nvmlist2.config = `"D:\VM\Kali\Kali.vmx`"`r`n"
$vmw = @(Format-VmVmware -Inventaire $vmls)
ok 'deux machines VMware'     (Get-Nombre $vmw) 2
ok 'le nom vient du .vmx'     $vmw[0].nom 'Ubuntu'
ok 'le chemin est le dossier' $vmw[1].chemin 'D:\VM\Kali'
ok 'les autres lignes sont ignorees' (Get-Nombre (Format-VmVmware -Inventaire 'vmlist1.DisplayName = "x"')) 0
ok 'un inventaire vide'       (Get-Nombre (Format-VmVmware -Inventaire '')) 0

$hv = @(Format-VmHyperV -Machines @((Obj @{ Name='Serveur'; Path='C:\Hyper-V\Serveur' })))
ok 'Hyper-V repris'           $hv[0].nom 'Serveur'
ok 'sans nom, rien'           (Get-Nombre (Format-VmHyperV -Machines @((Obj @{ Path='x' })))) 0
ok 'vm declare'               ($CouverturesScan.Contains('vm')) $true

"--- archives mail ---"
ok 'mail declare'             ($CouverturesScan.Contains('mail')) $true
ok 'quatre emplacements connus' ($DossiersMail.Count -ge 4) $true
ok 'le .pst est cherche'      ([bool](@($DossiersMail | Where-Object { $_ -like '*.pst' }).Count)) $true
ok 'le .ost aussi'            ([bool](@($DossiersMail | Where-Object { $_ -like '*.ost' }).Count)) $true

"--- BitLocker ---"
# Le point entier de cette famille : la cle de recuperation ne doit JAMAIS
# sortir. Le protecteur en porte une, la sortie n'en porte que le type.
function Prot($t, $mdp){ return (Obj @{ KeyProtectorType=$t; RecoveryPassword=$mdp }) }
$chiffre = @(Format-Bitlocker -Volumes @((Obj @{
    MountPoint='C:'; ProtectionStatus='On'
    KeyProtector=@((Prot 'Tpm' ''), (Prot 'RecoveryPassword' '123456-654321-111111-222222-333333-444444-555555-666666')) })))
ok 'un volume chiffre'        (Get-Nombre $chiffre) 1
ok 'le volume est nomme'      $chiffre[0].volume 'C:'
ok 'chiffre'                  $chiffre[0].chiffre $true
ok 'une cle existe'           $chiffre[0].cleExiste $true
ok 'le type est lisible'      ($chiffre[0].protecteurs -contains 'mot de passe de recuperation') $true
# La verification qui compte : les 48 chiffres ne sont nulle part.
$texte = ($chiffre | ConvertTo-Json -Depth 5)
ok 'la cle n est PAS relevee' ($texte -notmatch '123456-654321') $true
ok 'et la page le dit'        ($chiffre[0].quoi -like '*ne la relevera jamais*') $true

$sansCle = @(Format-Bitlocker -Volumes @((Obj @{ MountPoint='D:'; ProtectionStatus='On'; KeyProtector=@((Prot 'Tpm' '')) })))
ok 'chiffre sans cle de secours' $sansCle[0].cleExiste $false
ok 'et on previent'              ($sansCle[0].quoi -like '*carte mere*') $true

$clair = @(Format-Bitlocker -Volumes @((Obj @{ MountPoint='E:'; ProtectionStatus='Off'; KeyProtector=@() })))
ok 'un volume en clair'       $clair[0].chiffre $false
ok 'rien a prevoir'           ($clair[0].quoi -like '*rien a prevoir*') $true
ok 'sans lettre, rien'        (Get-Nombre (Format-Bitlocker -Volumes @((Obj @{ ProtectionStatus='On' })))) 0
ok 'liste vide'               (Get-Nombre (Format-Bitlocker -Volumes @())) 0
ok 'bitlocker declare'        ($CouverturesScan.Contains('bitlocker')) $true


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

"--- antivirus ---"
$av = @(Format-Antivirus -Produits @(
    (Obj @{ displayName='Windows Defender' }), (Obj @{ displayName='Bitdefender Antivirus Plus' })))
ok 'deux produits'           (Get-Nombre $av) 2
ok 'Defender est integre'    $av[0].integre $true
ok 'et revient tout seul'    ($av[0].quoi -like '*tout seul*') $true
ok 'le tiers ne l est pas'   $av[1].integre $false
ok 'et parle de licence'     ($av[1].quoi -like '*abonnement*') $true
ok 'sans nom, rien'          (Get-Nombre (Format-Antivirus -Produits @((Obj @{ })))) 0

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

"--- gestionnaires de paquets ---"
$dn = @(Format-PaquetsDotnet -Lignes @(
    'Package Id      Version      Commands',
    '--------------------------------------',
    'dotnet-ef       9.0.1        dotnet-ef',
    'csharpier       0.30.2       csharpier'))
ok 'deux outils dotnet'      (Get-Nombre $dn) 2
ok 'la commande est ecrite'  ($dn[0].commande -like 'dotnet tool install -g dotnet-ef*') $true
ok 'l entete est ignoree'    (@($dn | Where-Object { $_.id -eq 'Package' }).Count) 0

$ps = @(Format-ModulesPowerShell -Modules @((Obj @{ Name='PSReadLine'; Version='2.3.5' })))
ok 'un module PowerShell'    $ps[0].id 'PSReadLine'
ok 'avec sa commande'        ($ps[0].commande -like 'Install-Module PSReadLine*') $true

$cg = @(Format-PaquetsCargo -Lignes @('ripgrep v14.1.0:', '    rg', 'bat v0.24.0:', '    bat'))
ok 'deux paquets cargo'      (Get-Nombre $cg) 2
# Les binaires fournis sont indentes : les compter ferait doubler la liste.
ok 'les binaires sont ignores' (@($cg | Where-Object { $_.id -eq 'rg' }).Count) 0
ok 'la version est lue'      $cg[0].version '14.1.0'

"--- imprimantes ---"
$imp = @(Format-Imprimantes -Imprimantes @(
    (Obj @{ Name='Microsoft Print to PDF'; DriverName='x'; PortName='PORTPROMPT:' }),
    (Obj @{ Name='Brother DCP-L2530DW'; DriverName='Brother DCP'; PortName='IP_192.168.1.50' }),
    (Obj @{ Name='Canon MG3600'; DriverName='Canon Inkjet'; PortName='USB001' })))
ok 'les virtuelles sont ecartees' (Get-Nombre $imp) 2
ok 'la reseau est reconnue'  $imp[0].reseau $true
ok 'la locale non'           $imp[1].reseau $false
ok 'le pilote est garde'     $imp[1].pilote 'Canon Inkjet'
ok 'et la ligne le dit'      ($imp[1].quoi -like '*pilote*') $true
ok 'imprimantes declarees'   ($CouverturesScan.Contains('imprimantes')) $true

"--- Wi-Fi : les noms, jamais les cles ---"
$wf = @(Format-ProfilsWifi -Lignes @(
    'Profils sur l interface Wi-Fi :',
    '    Profil Tous les utilisateurs     : Livebox-1234',
    '    Profil Tous les utilisateurs     : Bureau-5G',
    '    Profil Tous les utilisateurs     : Livebox-1234'))
ok 'deux reseaux, sans doublon' (Get-Nombre $wf) 2
ok 'le nom est propre'       $wf[0].nom 'Livebox-1234'
ok 'et la ligne dit pourquoi pas la cle' ($wf[0].quoi -like '*jamais la cle*') $true
$wfEn = @(Format-ProfilsWifi -Lignes @('    All User Profile     : HomeNet'))
ok 'l anglais marche aussi'  $wfEn[0].nom 'HomeNet'
ok 'liste vide'              (Get-Nombre (Format-ProfilsWifi -Lignes @())) 0
ok 'wifi declare'            ($CouverturesScan.Contains('wifi')) $true

"--- identifiants : les cibles, jamais les secrets ---"
$idt = @(Format-Identifiants -Lignes @(
    '    Cible : Domain:target=nas.local',
    '    Type : Mot de passe generique',
    '    Cible : virtualapp/didlogical',
    '    Cible : Domain:target=nas.local'))
ok 'une cible, sans doublon' (Get-Nombre $idt) 1
ok 'Windows est ecarte'      (@($idt | Where-Object { $_.cible -like 'virtualapp*' }).Count) 0
ok 'et la ligne le dit'      ($idt[0].quoi -like '*jamais le mot de passe*') $true
ok 'identifiants declares'   ($CouverturesScan.Contains('identifiants')) $true

"--- polices ---"
$fontes = New-Object PSObject
$fontes | Add-Member -NotePropertyName 'Arial (TrueType)' -NotePropertyValue 'arial.ttf'
$fontes | Add-Member -NotePropertyName 'Inter (TrueType)' -NotePropertyValue 'C:\Users\a\AppData\Local\Microsoft\Windows\Fonts\Inter.ttf'
$fontes | Add-Member -NotePropertyName 'PSPath' -NotePropertyValue 'x'
$pol = @(Format-Polices -Entrees $fontes -Portee 'machine')
ok 'les deux sont vues'      (Get-Nombre $pol) 2
ok 'le suffixe est retire'   $pol[0].nom 'Arial'
ok 'PSPath est ignore'       (@($pol | Where-Object { $_.nom -eq 'PSPath' }).Count) 0
ok 'polices declarees'       ($CouverturesScan.Contains('polices')) $true

"--- lecteurs reseau ---"
$lec = @(Format-LecteursReseau -Lecteurs @(
    (Obj @{ LocalPath='Z:'; RemotePath='\\nas\partage' }), (Obj @{ LocalPath='Y:'; RemotePath='' })))
ok 'un lecteur retenu'       (Get-Nombre $lec) 1
ok 'la cible est reprise'    $lec[0].cible '\\nas\partage'
ok 'lecteurs declares'       ($CouverturesScan.Contains('lecteurs')) $true

"--- lancement au demarrage ---"
$dem = @(Format-Demarrage -Entrees @(
    (Obj @{ Name='Discord'; Command='C:\...\Update.exe'; Location='HKU\...\Run' }),
    (Obj @{ Command='x' })))
ok 'une entree nommee'       (Get-Nombre $dem) 1
ok 'la commande est gardee'  ($dem[0].commande -like '*Update.exe*') $true
ok 'demarrage declare'       ($CouverturesScan.Contains('demarrage')) $true

"--- taches planifiees ---"
$tac = @(Format-TachesPlanifiees -Taches @(
    (Obj @{ TaskPath='\'; TaskName='Sauvegarde perso'; Author='antoni'; State='Ready' }),
    (Obj @{ TaskPath='\Microsoft\Windows\Defrag\'; TaskName='ScheduledDefrag'; Author='Microsoft'; State='Ready' }),
    (Obj @{ TaskPath='\'; TaskName='OneDrive'; Author='Microsoft Corporation'; State='Ready' })))
# Windows en pose plusieurs centaines : n'en garder qu'une est le but.
ok 'une seule tache a soi'   (Get-Nombre $tac) 1
ok 'la bonne'                $tac[0].nom 'Sauvegarde perso'
ok 'taches declarees'        ($CouverturesScan.Contains('taches')) $true

"--- pare-feu ---"
$pf = @(Format-ReglesPareFeu -Regles @(
    (Obj @{ DisplayName='Serveur local 8080'; Group=''; Enabled='True'; Direction='Inbound'; Action='Allow' }),
    (Obj @{ DisplayName='Steam'; Group='Steam'; Enabled='True'; Direction='Inbound'; Action='Allow' }),
    (Obj @{ DisplayName='Desactivee'; Group=''; Enabled='False'; Direction='Inbound'; Action='Allow' }),
    (Obj @{ DisplayName='Sortante'; Group=''; Enabled='True'; Direction='Outbound'; Action='Allow' }),
    (Obj @{ DisplayName='Blocage'; Group=''; Enabled='True'; Direction='Inbound'; Action='Block' })))
ok 'une seule regle a soi'   (Get-Nombre $pf) 1
ok 'la bonne'                $pf[0].nom 'Serveur local 8080'
ok 'et on dit de la relire'  ($pf[0].quoi -like '*relire*') $true
ok 'pare-feu declare'        ($CouverturesScan.Contains('pareFeu')) $true

"--- associations de fichiers ---"
$aso = @(Format-Associations -Choix @(
    (Obj @{ extension='.pdf'; progId='AcroExch.Document' }),
    (Obj @{ extension='.txt'; progId='notepad' }),
    (Obj @{ extension='.md';  progId='VSCode.md' }),
    (Obj @{ extension='.png'; progId='AppX43hnxtbyyps62' })))
ok 'les banales sont ecartees' (@($aso | Where-Object { $_.extension -eq '.txt' }).Count) 0
ok 'les AppX aussi'            (@($aso | Where-Object { $_.programme -like 'AppX*' }).Count) 0
ok 'deux associations a soi'   (Get-Nombre $aso) 2
# Windows signe ce choix pour la machine : la ligne ne doit pas promettre une
# restauration qui ne marchera pas.
ok 'et on dit que ca ne se restaure pas' ($aso[0].quoi -like '*ne se restaure pas*') $true
ok 'associations declarees'    ($CouverturesScan.Contains('associations')) $true


if($script:ko){"`n$($script:ko) TEST(S) EN ECHEC"; exit 1} else {"`nTOUS LES TESTS POWERSHELL PASSENT"}
