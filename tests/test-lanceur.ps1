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
ok 'six actions proposees'         $a.Count 6
ok 'toutes realisables'            (@($a | Where-Object { -not $_.possible })).Count 0
ok 'chacune a un intitule'         (@($a | Where-Object { [string]::IsNullOrWhiteSpace($_.titre) })).Count 0
ok 'et une explication'            (@($a | Where-Object { [string]::IsNullOrWhiteSpace($_.detail) })).Count 0
ok 'et une duree annoncee'         (@($a | Where-Object { [string]::IsNullOrWhiteSpace($_.duree) })).Count 0
ok 'identifiants uniques'          (@($a.id | Sort-Object -Unique)).Count 6

# Les deux premieres actions disent SUR QUELLE MACHINE on est : c'est la seule
# question a laquelle on ne peut pas repondre a la place de l'utilisateur.
ok 'une action pour l ancien PC'   (@($a | Where-Object { $_.titre -match 'ANCIEN' })).Count 1
ok 'une action pour le nouveau'    (@($a | Where-Object { $_.titre -match 'NOUVEAU' })).Count 1

# Chaque action mene quelque part : un script a lancer, ou un fichier a ouvrir.
ok 'chaque action mene quelque part' (@($a | Where-Object {
      -not ($_.PSObject.Properties['script'] -or $_.PSObject.Properties['fichier']) })).Count 0
# Et ce quelque part existe vraiment dans le depot.
$cibles = @($a | ForEach-Object {
    if ($_.PSObject.Properties['script']) { $_.script } else { $_.fichier } })
ok 'les cibles existent'           (@($cibles | Where-Object {
      -not (Test-Path -LiteralPath (Join-Path $racine $_)) })).Count 0

"`n--- dans un dossier incomplet ---"
$t = Join-Path ([System.IO.Path]::GetTempPath()) ("lanceur-" + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $t -Force
Copy-Item (Join-Path $racine 'scan-pc.ps1') $t
$b = @(Get-ActionsMigration -Racine $t)
ok 'les actions restent montrees'  $b.Count 6
ok 'mais aucune n est realisable'  (@($b | Where-Object { $_.possible })).Count 0
# scan-pc.ps1 est la, mais il ne tourne pas sans lib-detection.ps1 : l'action
# doit le dire au lieu de laisser lancer un script qui echouera.
$ancien = $b | Where-Object { $_.id -eq 'ancien' }
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
$inventaire = $a | Where-Object { $_.id -eq 'ancien' }
ok 'elle nomme un onglet du site' ((@($inventaire.suite) -join ' ') -match 'Apps|Donnees') $true
$verif = $a | Where-Object { $_.id -eq 'nouveau' }
ok 'elle parle des pilotes'       ((@($verif.suite) -join ' ') -match 'pilote') $true

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
# On copie VERS un dossier, on restaure DEPUIS un dossier : se tromper de sens
# ecraserait la sauvegarde avec le contenu de la machine neuve.
$emporter = $a | Where-Object { $_.id -eq 'emporter' }
$remettre = $a | Where-Object { $_.id -eq 'remettre' }
ok 'emporter ecrit vers Destination' $emporter.argument 'Destination'
ok 'remettre lit depuis Source'      $remettre.argument 'Source'
ok 'les deux demandent un dossier'   (@($emporter.dossier, $remettre.dossier) -contains $false) $false
# L'ordre compte : installer les logiciels d'abord, reposer les reglages apres.
ok 'remettre previent sur l ordre'   ((@($remettre.suite) -join ' ') -match 'APR[EÈ]S avoir install[eé]') $true

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
foreach ($f in @('scan-pc.ps1', 'verifier-pc.ps1', 'sauvegarder-configs.ps1',
                 'verifier-sauvegardes.ps1', 'restaurer-configs.ps1', 'migration-pc.ps1')) {
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
if ($script:ko -gt 0) { Write-Host "$script:ko EN ECHEC" -ForegroundColor Red; exit 1 }
Write-Host "LANCEUR OPERATIONNEL" -ForegroundColor Green
