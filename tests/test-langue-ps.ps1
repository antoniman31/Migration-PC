# Les scripts en anglais ne doivent plus ecrire de francais.
#
#   pwsh -File tests/test-langue-ps.ps1
#
# Ecrit a l'envers des autres, comme tests/test-anglais.js : il cherche ce qui
# NE DOIT PAS etre la. Un test qui verifie la presence de traductions se
# satisfait de la premiere ; un test qui refuse le francais ne passe que quand
# il n'en reste plus.
#
# CE QU'IL NE REGARDE PAS, et c'est voulu : tout ce qui part dans le fichier
# JSON. lib-detection.ps1 y ecrit des noms de categories et de logiciels que la
# page relit et normalise, et tests/cles-normalisation.json est le contrat
# partage entre les deux. Les traduire casserait la reconciliation. Seul ce
# qu'un humain lit dans la console est examine.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$depot = Split-Path $PSScriptRoot -Parent
$racine = Join-Path $depot 'scripts'

$script:ko = 0
function ok($libelle, $obtenu, $attendu) {
    $bon = ($obtenu -eq $attendu)
    $marque = if ($bon) { '  ok  ' } else { ' FAIL ' }
    Write-Host "$marque$libelle -> $obtenu$(if (-not $bon) { " (attendu $attendu)" })"
    if (-not $bon) { $script:ko++ }
}

. (Join-Path $racine 'lib-langue.ps1')
. (Join-Path $racine 'lanceur-actions.ps1')

"--- la mecanique ---"
ok 'la langue demandee gagne'        (Resolve-Langue 'en') 'en'
ok 'et le francais aussi'            (Resolve-Langue 'fr') 'fr'
# Une valeur inconnue ne doit pas arreter un scan : elle avertit et retombe sur
# la machine. On verifie seulement que ca rend une langue connue.
ok 'une valeur inconnue rend quand meme une langue' `
    ((Resolve-Langue 'klingon' 3>$null) -in @('fr', 'en')) $true

[void](Set-Langue 'fr')
ok 'en francais, la cle est rendue'  (Tr 'non installe, ignore') 'non installe, ignore'
[void](Set-Langue 'en')
ok 'en anglais, la traduction'       (Tr 'non installe, ignore') 'not installed, skipped'
ok 'une cle absente retombe sur le francais' `
    (Tr 'Une phrase que personne n a traduite') 'Une phrase que personne n a traduite'

# LE PIEGE QUI A MORDU. PowerShell deroule un tableau d'un seul element dans un
# test booleen : @(0) est FAUX. « if ($Trous) » laissait donc « {0} entrees »
# a l'ecran, et seulement quand le compte valait zero — le cas le plus courant
# sur une machine ou une source est absente, donc celui qu'on voit le plus.
ok 'un trou rempli par zero'         (Tr '{0} entrees' 0) '0 entries'
ok 'un trou rempli par un nombre'    (Tr '{0} entrees' 7) '7 entries'
ok 'un trou rempli par du vide'      (Tr '{0} a regler' '') ' to sort out'
ok 'deux trous'                      (Tr '{0} : ignore, {1}' 'Steam' 'zut') 'Steam: skipped, zut'

"--- l'habillage suit la langue affichee ---"
# Les phrases sont entieres dans la table et coupees a l'affichage : une coupe
# faite pour le francais ne survivrait pas a la traduction.
$long = 'un mot ' * 30
$lignes = @(Format-Paragraphe $long 4 7 40)
ok 'plusieurs lignes'                ($lignes.Count -gt 1) $true
ok 'aucune ne depasse la largeur'    (@($lignes | Where-Object { $_.Length -gt 40 })).Count 0
ok 'la premiere porte sa marge'      ($lignes[0].StartsWith('    un')) $true
ok 'les suivantes la marge de suite' ($lignes[1].StartsWith('       ')) $true

"--- les cles de la table se trouvent dans les scripts ---"
# Une cle recopiee de travers ne traduit rien et ne se voit pas a l'oeil : elle
# rend simplement le francais, comme si la traduction n'existait pas. Le meme
# controle existe pour la page, et il y a deja attrape nuit cles de categories
# ecrites sans leur emoji.
$source = ''
foreach ($f in (Get-ChildItem -LiteralPath $racine -Filter '*.ps1')) {
    if ($f.Name -eq 'lib-langue.ps1') { continue }   # la table ne se cherche pas elle-meme
    $source += [System.IO.File]::ReadAllText($f.FullName)
}
$orphelines = @()
foreach ($cle in $script:MESSAGES.Keys) {
    # La cle telle qu'elle est ecrite dans le code, en double ou simple quote.
    if ($source.Contains($cle) -or $source.Contains($cle.Replace("'", "''"))) { continue }
    $orphelines += $cle
}
ok 'aucune traduction orpheline'     ($orphelines -join ' | ') ''

"--- aucun francais dans la sortie anglaise ---"
# Des mots francais qui ne sont pas des mots anglais. « installation » et
# « information » s'ecrivent pareil : les mettre ici produirait de fausses
# alertes a chaque passage.
$motsFr = @('le', 'la', 'les', 'des', 'une', 'pour', 'sur', 'dans', 'avec', 'sans',
    'tout', 'tous', 'cette', 'aucun', 'aucune', 'rien', 'votre', 'vos', 'est', 'sont',
    'ignore', 'installe', 'absent', 'entrees', 'entree', 'jeux', 'jeu', 'fichier',
    'dossier', 'materiel', 'peripherique', 'peripheriques', 'pilote', 'pilotes',
    'logiciel', 'logiciels', 'registre', 'fournisseur', 'fournisseurs', 'composant',
    'composants', 'quitter', 'choix', 'reponse', 'suivante', 'etape', 'ecrit',
    'debranchez', 'branchez', 'lancez', 'relancez', 'scannez', 'annule', 'termine')

function FrancaisDans($texte) {
    $trouves = @()
    # Les accents d'abord : ils attrapent « Réinitialiser » que la liste ignore.
    foreach ($m in [regex]::Matches($texte, '\S*[éèêëàâäçùûüîïôöœæ]\S*')) {
        if ($trouves -notcontains "accent: $($m.Value)") { $trouves += "accent: $($m.Value)" }
    }
    # Puis les mots, qui attrapent « Passer » laisse tel quel — sans accent, la
    # premiere detection ne le verrait jamais.
    $plat = ($texte -replace '\s+', ' ')
    foreach ($mot in ($plat.ToLower() -split '[^a-z0-9]+')) {
        if (-not $mot) { continue }
        if ($motsFr -notcontains $mot) { continue }
        if ($trouves -notcontains "mot: $mot") { $trouves += "mot: $mot" }
    }
    return $trouves
}

# Le scan tourne dans un dossier a lui : il ecrit des fichiers, et on ne veut
# pas les semer dans le depot.
$bac = Join-Path ([System.IO.Path]::GetTempPath()) ("mpc-langue-" + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $bac)
try {
    Copy-Item -Path (Join-Path $racine '*.ps1') -Destination $bac
    $sortie = & pwsh -NoProfile -File (Join-Path $bac 'scan-pc.ps1') `
        -Role source -PasDOuverture -Langue en 2>&1 | Out-String
    $coupables = @(FrancaisDans $sortie)
    foreach ($c in ($coupables | Select-Object -First 12)) { Write-Host "      $c" }
    ok 'rien de francais dans la sortie du scan' $coupables.Count 0
    # Et un trou laisse vide serait passe inapercu : « {0} entrees » n'est ni
    # accentue ni un mot francais.
    ok 'aucun trou laisse en place'  ($sortie -match '\{\d\}') $false
} finally {
    Remove-Item -LiteralPath $bac -Recurse -Force -ErrorAction SilentlyContinue
}

"--- ni dans le menu et ses actions ---"
[void](Set-Langue 'en')
$textes = @()
foreach ($a in @(Get-ActionsMigration -Racine $racine)) {
    $textes += $a.titre; $textes += $a.detail; $textes += $a.duree
    if ($a.suite) { $textes += @($a.suite) }
    if (-not $a.possible) { $textes += (Get-MessageManquants $a.manquants) }
}
$textes += @(Get-Parcours)
$textes += @(Get-InviteInstallation -Identifiants @('7zip.7zip'))
$textes += @(Get-InviteInstallation -Identifiants @())
$textes += (Get-RoleSuggere -Racine $racine).raison
$coupablesMenu = @(FrancaisDans ($textes -join ' '))
foreach ($c in ($coupablesMenu | Select-Object -First 12)) { Write-Host "      $c" }
ok 'rien de francais dans le menu'   $coupablesMenu.Count 0

"--- et le francais reste intact ---"
# Le but n'est pas d'avoir traduit, c'est d'avoir traduit SANS abimer l'original.
[void](Set-Langue 'fr')
$fr = @(Get-ActionsMigration -Racine $racine)
ok 'la source garde son intitule'    $fr[0].titre 'Ce PC est la SOURCE (celui que je quitte)'
ok 'le parcours previent du formatage' `
    ((((@(Get-Parcours)) -join ' ') -replace '\s+', ' ') -match 'AVANT de formater') $true
# Les deux mots de confirmation valent, dans les deux langues : quelqu'un qui a
# lu la procedure en francais ne doit pas rester dehors sur une console
# anglaise, pour une action qui installe des logiciels.
ok 'INSTALLER est accepte'            (Test-Confirmation 'INSTALLER') $true
ok 'INSTALL aussi'                    (Test-Confirmation 'install') $true
ok 'et rien d autre'                  (Test-Confirmation 'oui') $false

Write-Host ""
if ($script:ko -gt 0) { Write-Host "$script:ko EN ECHEC"; exit 1 }
Write-Host "SCRIPTS : PLUS AUCUN FRANCAIS EN ANGLAIS"
