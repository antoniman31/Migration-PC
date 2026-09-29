# Le lanceur : ce qu'il propose, et ce qu'il fait quand un fichier manque.
#
# L'interface graphique elle-meme ne se teste pas ici — System.Windows.Forms
# n'existe pas hors de Windows Desktop. C'est pourquoi la liste des actions et
# leurs verifications vivent dans lanceur-actions.ps1, separees de l'affichage :
# cette partie-la se teste partout, et c'est elle qui decide de tout.
#
#   pwsh -File tests/test-lanceur.ps1

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$depot = Split-Path $PSScriptRoot -Parent
# Les scripts sont ranges dans scripts\ : a la racine il ne reste que le
# fichier a double-cliquer et la page. Un inconnu qui ouvre le dossier ne
# doit pas avoir a deviner lequel des vingt fichiers lancer.
$racine = Join-Path $depot 'scripts'
. (Join-Path $racine 'lanceur-actions.ps1')

$script:ko = 0
function ok($libelle, $obtenu, $attendu) {
    $bon = ($obtenu -eq $attendu)
    $marque = if ($bon) { '  ok  ' } else { ' FAIL ' }
    Write-Host "$marque$libelle -> $obtenu$(if (-not $bon) { " (attendu $attendu)" })"
    if (-not $bon) { $script:ko++ }
}

"--- dans un dossier complet ---"
$a = @(Get-ActionsMigration -Racine $racine)
ok 'quatre actions proposees'      $a.Count 4
# « Installer ce qui manque » a besoin du fichier ecrit par le scan de la
# cible. Dans le depot il n'existe pas, et c'est normal : l'action reste
# montree, grisee, avec la raison. Les trois autres sont toujours realisables.
$sansInstall = @($a | Where-Object { $_.id -ne 'installer' })
ok 'les trois autres realisables'  (@($sansInstall | Where-Object { -not $_.possible })).Count 0
ok 'chacune a un intitule'         (@($a | Where-Object { [string]::IsNullOrWhiteSpace($_.titre) })).Count 0
ok 'et une explication'            (@($a | Where-Object { [string]::IsNullOrWhiteSpace($_.detail) })).Count 0
ok 'et une duree annoncee'         (@($a | Where-Object { [string]::IsNullOrWhiteSpace($_.duree) })).Count 0
ok 'identifiants uniques'          (@($a.id | Sort-Object -Unique)).Count 4

# Les deux premieres actions disent SUR QUELLE MACHINE on est : c'est la seule
# question a laquelle on ne peut pas repondre a la place de l'utilisateur.
# Le vocabulaire est source/cible et non ancien/nouveau : « le meme PC que je
# viens de reinstaller » n'a rien d'un nouveau PC, et c'est pourtant le cas le
# plus courant.
ok 'une action pour la source'     (@($a | Where-Object { $_.titre -match 'SOURCE' })).Count 1
ok 'une action pour la cible'      (@($a | Where-Object { $_.titre -match 'CIBLE' })).Count 1
ok 'plus de vocabulaire ancien/nouveau' (@($a | Where-Object { $_.titre -match 'ANCIEN|NOUVEAU' })).Count 0

# Chaque action mene quelque part : un script a lancer, un fichier a ouvrir, ou
# winget a jouer sur une liste deja calculee.
ok 'chaque action mene quelque part' (@($a | Where-Object {
      -not ($_.PSObject.Properties['script'] -or $_.PSObject.Properties['fichier'] `
            -or $_.PSObject.Properties['winget']) })).Count 0
# Et ce quelque part existe vraiment dans le depot. L'installation est a part :
# ce qu'elle joue est produit par un scan, pas versionne.
$cibles = @($sansInstall | ForEach-Object {
    if ($_.PSObject.Properties['script']) { $_.script } else { $_.fichier } })
ok 'les cibles existent'           (@($cibles | Where-Object {
      -not (Test-Path -LiteralPath (Join-Path $racine $_)) })).Count 0

"`n--- dans un dossier incomplet ---"
$t = Join-Path ([System.IO.Path]::GetTempPath()) ("lanceur-" + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $t -Force
Copy-Item (Join-Path $racine 'scan-pc.ps1') $t
$b = @(Get-ActionsMigration -Racine $t)
ok 'les actions restent montrees'  $b.Count 4
ok 'mais aucune n est realisable'  (@($b | Where-Object { $_.possible })).Count 0
# scan-pc.ps1 est la, mais il ne tourne pas sans lib-detection.ps1 : l'action
# doit le dire au lieu de laisser lancer un script qui echouera.
$ancien = $b | Where-Object { $_.id -eq 'source' }
ok 'le fichier manquant est nomme' ($ancien.manquants -contains 'lib-detection.ps1') $true
ok 'le script present n est pas signale' ($ancien.manquants -contains 'scan-pc.ps1') $false
$msg = Get-MessageManquants $ancien.manquants
ok 'le message nomme le fichier'   ($msg -match 'lib-detection') $true
ok 'et dit quoi faire'             ($msg -match 'dossier entier') $true
ok 'un message vide si rien ne manque' (Get-MessageManquants @()) ''

Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue

"`n--- ce qui se passe apres ---"
# Lancer le script n'est que la moitie du chemin : savoir quoi faire ensuite
# sur le site est le reste, et c'est la que les gens se perdent.
ok 'chaque action dit la suite' (@($a | Where-Object {
      -not $_.PSObject.Properties['suite'] -or @($_.suite).Count -eq 0 })).Count 0
$inventaire = $a | Where-Object { $_.id -eq 'source' }
ok 'elle nomme un onglet du site' ((@($inventaire.suite) -join ' ') -match 'Logiciels|Pilotes') $true
$verif = $a | Where-Object { $_.id -eq 'cible' }
ok 'elle parle des pilotes'       ((@($verif.suite) -join ' ') -match 'pilote') $true
# Le meme script des deux cotes, distingue par son seul argument : c'est ce
# qui rend « PC neuf » et « meme PC reinstalle » identiques.
ok 'les deux lancent le meme script' ($inventaire.script) ($verif.script)
ok 'la source se declare telle'   ((@($inventaire.arguments) -join ' ')) '-Role source'
# L'installation est la seule action qui change la machine, et la seule qui n'a
# pas de script a lancer : elle joue une liste deja calculee.
$inst = $a | Where-Object { $_.id -eq 'installer' }
ok 'une action pour installer'     ($null -ne $inst) $true
ok 'elle passe par winget'         $inst.winget $true
ok 'sans script a lancer'          ($inst.PSObject.Properties['script']) $null
ok 'et elle attend le fichier du scan' ($inst.manquants -contains '..\winget-restant.json') $true
ok 'et la cible aussi'            ((@($verif.arguments) -join ' ')) '-Role cible'

$parcours = @(Get-Parcours)
ok 'un parcours complet existe'   ($parcours.Count -gt 0) $true
$texte = $parcours -join ' '
# Les trois situations que la page sait traiter doivent y figurer : c'est la
# question posee par le lanceur, et la reponse doit couvrir les trois.
ok 'il couvre le changement de PC' ($texte -match "d'un PC vers un autre") $true
# Le motif tolere les deux graphies : ce qui compte est que le cas soit
# couvert, pas la facon dont le mot est accentue.
ok 'la reinstallation sur place'   ($texte -match 'r[eé]installez Windows') $true
ok 'et le cas des deux PC'         ($texte -match 'gardez les deux') $true
# Le piege le plus couteux du parcours : formater avant d'avoir verifie la copie.
ok 'il previent avant le formatage' ($texte -match 'AVANT de formater') $true
# Le projet ne copie plus rien : il liste. Une action qui donnerait a croire
# le contraire remettrait sur le dos du programme une sauvegarde qu'il ne fait
# pas, ce qui est la pire promesse possible avant un formatage.
ok 'plus d action de copie'        (@($a | Where-Object { $_.id -in @('emporter', 'remettre', 'sauvegardes') })).Count 0
ok 'et le parcours le dit'         ($texte -match 'LISTE, il ne copie rien') $true

"`n--- les fichiers du lanceur ---"
foreach ($f in @('migration-pc.ps1', 'lanceur-actions.ps1')) {
    ok "« $f » existe" (Test-Path -LiteralPath (Join-Path $racine $f)) $true
}
# Un .bat en fins de ligne Unix ne s'execute pas correctement sous Windows.
# Les deux raccourcis numerotes sont partis : trois fichiers qui se
# ressemblent desorientaient plus qu'un seul point d'entree.
foreach ($f in @('Migration PC.bat')) {
    # Il reste a la racine : c'est le seul fichier qu'on double-clique.
    $brut = [System.IO.File]::ReadAllText((Join-Path $depot $f))
    ok "« $f » en fins de ligne Windows" ($brut -match "`r`n") $true
    ok "« $f » contourne le blocage d execution" ($brut -match 'ExecutionPolicy Bypass') $true
}

# Le lanceur doit pouvoir basculer en mode texte : sans Windows Desktop, il n'y
# a pas d'interface graphique, et une fenetre qui ne s'ouvre pas sans rien dire
# serait pire que pas de fenetre.
$source = Get-Content (Join-Path $racine 'migration-pc.ps1') -Raw -Encoding UTF8
ok 'le menu texte est le seul mode' ($source -match 'Show-MenuTexte') $true
# La fenetre graphique a ete retiree : elle etait le seul morceau du projet
# qu'aucun test ne pouvait exercer, WinForms ne se pilotant pas sur une machine
# sans ecran. Ce qui la remplacerait doit rester dehors.
$avecFenetre = @()
foreach ($f in @(Get-ChildItem -Path $racine -Filter '*.ps1' -File)) {
    $t = [System.IO.File]::ReadAllText($f.FullName)
    if ($t -match 'System\.Windows\.Forms|System\.Drawing') { $avecFenetre += $f.Name }
}
ok 'aucune dependance graphique'   ($avecFenetre -join ', ') ''

# Les accents des textes affiches n'arrivent en clair que si la sortie est en
# UTF-8 : sans cela la console de Windows rend du charabia.
$sansUtf8 = @()
foreach ($f in @('scan-pc.ps1', 'migration-pc.ps1')) {
    $t = [System.IO.File]::ReadAllText((Join-Path $racine $f))
    if ($t -notmatch 'OutputEncoding') { $sansUtf8 += $f }
}
ok 'la sortie console est en UTF-8' ($sansUtf8 -join ', ') ''

# Le menu est ce que les gens lisent : il doit etre en francais correct.
. (Join-Path $racine 'lanceur-actions.ps1')
$textes = @()
foreach ($a in @(Get-ActionsMigration -Racine $racine)) {
    $textes += $a.titre
    $textes += $a.detail
}
$textes += (Get-Parcours)
ok 'le menu porte des accents'     (@($textes | Where-Object { $_ -match '[éèêàçùôû]' }).Count -gt 0) $true
# Mojibake : la marque d'un UTF-8 relu comme de l'ANSI.
ok 'et aucun n est abime'          (@($textes | Where-Object { $_ -match 'Ã|Â|â€' }).Count) 0
# $args est la variable automatique des arguments non lies : l'ecraser dans un
# script est un piege classique, et le parseur le voit.
$ecrases = @()
$arbre = [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $racine 'migration-pc.ps1'), [ref]$null, [ref]$null)
$arbre.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true) |
    ForEach-Object {
        $gauche = $_.Left
        if ($gauche -is [System.Management.Automation.Language.VariableExpressionAst] -and
            $gauche.VariablePath.UserPath -eq 'args') { $ecrases += $gauche.Extent.StartLineNumber }
    }
ok 'la variable automatique $args n est pas ecrasee' ($ecrases -join ', ') ''

Write-Host ""
Write-Host "--- les chemins avec une espace ---" -ForegroundColor Cyan
# Start-Process -ArgumentList recolle les elements avec des espaces sans les
# proteger : « D:\Migration PC » se coupait en deux et powershell.exe refusait
# la ligne entiere. Le dossier de ce projet s'appelle « Migration PC » : ce
# n'etait pas un cas tordu, c'etait le cas normal.
ok 'un chemin avec espace est protege' (Format-Argument 'D:\Migration PC\scan-pc.ps1') '"D:\Migration PC\scan-pc.ps1"'
ok 'un chemin sans espace reste nu'    (Format-Argument 'D:\scan-pc.ps1') 'D:\scan-pc.ps1'
ok 'un guillemet est double'           (Format-Argument 'a"b') '"a""b"'
ok 'une chaine vide reste un argument' (Format-Argument '') '""'
$ligne = Get-LigneCommande @('-File', 'D:\Migration PC\x.ps1', '-Destination', 'E:\Sauvegarde du 12')
ok 'la ligne garde ses quatre morceaux' $ligne.Count 4
ok 'et protege les deux chemins' (($ligne | Where-Object { $_ -match '^"' }).Count) 2

# Le vrai lancement, de bout en bout : un script appele depuis un dossier dont
# le nom contient une espace, avec un argument qui en contient une aussi.
$bac = Join-Path ([System.IO.Path]::GetTempPath()) ("mpc lanceur " + (Get-Random))
New-Item -ItemType Directory -Path $bac -Force | Out-Null
try {
    $cible = Join-Path $bac 'echo test.ps1'
    Set-Content -LiteralPath $cible -Value 'param([string]$Destination)' -Encoding UTF8
    Add-Content -LiteralPath $cible -Value 'Write-Output "RECU:[$Destination]"'
    $arrivee = Join-Path $bac 'un dossier a moi'
    $sortie  = Join-Path $bac 'sortie.txt'
    $p = @('-NoProfile', '-File', $cible, '-Destination', $arrivee)
    $exe = (Get-Process -Id $PID).Path
    Start-Process -FilePath $exe -ArgumentList (Get-LigneCommande $p) -Wait -NoNewWindow -RedirectStandardOutput $sortie
    $lu = (Get-Content -LiteralPath $sortie -Raw -Encoding UTF8).Trim()
    ok 'le script recoit le chemin entier' $lu "RECU:[$arrivee]"
} finally {
    Remove-Item $bac -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "--- de quel cote on est, deduit plutot que demande ---" -ForegroundColor Cyan
# Le menu ne posait qu'une question, et elle a une reponse mecanique : si la
# cle porte l'instantane d'une AUTRE machine, on est arrive sur la cible. Se
# tromper coutait la comparaison entiere, sans que rien ne le dise.

function Instantane([string]$Serie, [string]$Nom, [string]$Modele) {
    $m = [ordered]@{}
    if ($Serie)  { $m['serie']  = $Serie }
    if ($Nom)    { $m['nom']    = $Nom }
    if ($Modele) { $m['modele'] = $Modele }
    return [pscustomobject]@{ type = 'inventaire-migration-pc'; role = 'source'; machine = [pscustomobject]$m }
}

# Rien sur la cle : on n'a pas encore scanne, donc on est sur la source.
$r = Get-RoleSuggere -Instantane $null -SerieLocale 'ABC123' -NomLocal 'PC-NEUF'
ok 'sans instantane, aucun role impose' $r.role ''
ok 'et la raison le dit'                ($r.raison -match 'SOURCE') $true

# Deux numeros de serie differents : c'est le cas franc, et le seul ou l'on
# affirme quelque chose.
$r = Get-RoleSuggere -Instantane (Instantane 'SERIE-ANCIEN' 'PC-BUREAU' 'ROG STRIX B850-A') -SerieLocale 'SERIE-NEUF' -NomLocal 'PC-NEUF'
ok 'serie differente, donc la cible'    $r.role 'cible'
ok 'la raison nomme la machine vue'     ($r.raison -match 'ROG STRIX') $true

# Meme numero de serie : « je reinstalle ce PC-ci ». Genuinement ambigu, parce
# qu'on peut aussi refaire le relevé avant de formater. On ne devine pas.
$r = Get-RoleSuggere -Instantane (Instantane 'MEME-SERIE' 'PC-BUREAU' 'X') -SerieLocale 'MEME-SERIE' -NomLocal 'PC-BUREAU'
ok 'meme serie, on ne devine pas'       $r.role ''
ok 'et la raison explique les deux cas' ($r.raison -match 'CIBLE' -and $r.raison -match 'SOURCE') $true

# Pas de numero de serie — machine assemblee dont le SMBIOS est vide. On
# retombe sur le nom de machine, en le disant.
$r = Get-RoleSuggere -Instantane (Instantane '' 'PC-BUREAU' '') -SerieLocale '' -NomLocal 'PC-NEUF'
ok 'sans serie, le nom tranche'         $r.role 'cible'
ok 'et la raison avoue sa faiblesse'    ($r.raison -match 'Num[eé]ro de s[eé]rie indisponible') $true
$r = Get-RoleSuggere -Instantane (Instantane '' 'PC-BUREAU' '') -SerieLocale '' -NomLocal 'PC-BUREAU'
ok 'meme nom, on ne devine pas'         $r.role ''

# Un instantane sans aucune information de machine ne doit pas faire echouer le
# menu : Set-StrictMode rend une propriete absente fatale si on la lit mal.
$r = Get-RoleSuggere -Instantane ([pscustomobject]@{ type = 'inventaire-migration-pc' }) -SerieLocale 'ABC' -NomLocal 'PC'
ok 'un instantane muet ne casse rien'   $r.role ''
ok 'et la raison le dit'                ($r.raison -match 'rien ne permet') $true

# L'ordre du menu : le cote deduit passe en tete, et le reste garde le sien.
$ac = @(Get-ActionsMigration -Racine $racine -RoleSuggere 'cible')
ok 'la cible passe en premier'          $ac[0].id 'cible'
ok 'elle porte la marque'               $ac[0].suggere $true
ok 'les quatre actions restent la'      $ac.Count 4
ok 'la source reste accessible'         (@($ac | Where-Object { $_.id -eq 'source' })).Count 1
ok 'une seule est marquee'              (@($ac | Where-Object { $_.suggere })).Count 1
# L'ordre des non-proposees ne doit pas bouger : Sort-Object -Stable n'existe
# pas sous Windows PowerShell 5.1, d'ou le tri fait a la main.
ok 'le reste garde son ordre'           (@($ac | Where-Object { -not $_.suggere }).id -join ',') 'source,installer,checklist'
$ac = @(Get-ActionsMigration -Racine $racine -RoleSuggere '')
ok 'sans deduction, l ordre d origine'  ($ac.id -join ',') 'source,cible,installer,checklist'
ok 'et aucune marque'                   (@($ac | Where-Object { $_.suggere })).Count 0

# La lecture du fichier sur la cle : un JSON abime ne doit rien faire deviner.
$bacD = Join-Path ([System.IO.Path]::GetTempPath()) ("mpc deduction " + (Get-Random))
New-Item -ItemType Directory -Path $bacD -Force | Out-Null
try {
    ok 'sans fichier, rien a lire' ($null -eq (Get-InstantaneSourceSurCle -Racine $bacD)) $true
    Set-Content -LiteralPath (Join-Path $bacD 'instantane-source.json') -Value '{ ceci n est pas du json' -Encoding UTF8
    ok 'un JSON abime rend $null'  ($null -eq (Get-InstantaneSourceSurCle -Racine $bacD)) $true
    Set-Content -LiteralPath (Join-Path $bacD 'instantane-source.json') -Value '{"machine":{"serie":"S1"}}' -Encoding UTF8
    $lu = Get-InstantaneSourceSurCle -Racine $bacD
    ok 'un JSON valide est relu'   $lu.machine.serie 'S1'
    # Les scripts vivent dans scripts\ et le relais a cote de la page, un cran
    # au-dessus : il faut chercher les deux.
    $sous = Join-Path $bacD 'scripts'
    New-Item -ItemType Directory -Path $sous -Force | Out-Null
    $lu = Get-InstantaneSourceSurCle -Racine $sous
    ok 'trouve aussi un cran au-dessus' $lu.machine.serie 'S1'
} finally {
    Remove-Item $bacD -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
if ($script:ko -gt 0) { Write-Host "$script:ko EN ECHEC" -ForegroundColor Red; exit 1 }
Write-Host "LANCEUR OPERATIONNEL" -ForegroundColor Green
