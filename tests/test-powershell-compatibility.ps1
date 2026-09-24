# Windows PowerShell 5.1 — celui livre avec Windows, et celui qu'on obtient par
# double-clic — lit un .ps1 SANS marqueur d'encodage comme de l'ANSI, pas de
# l'UTF-8. « Clés SSH » y devient « ClÃ©s SSH », et ce texte part dans le JSON
# de l'inventaire, donc dans la page.
#
# Le marqueur (BOM) est la facon standard de lever l'ambiguite, et PowerShell 7
# le lit sans broncher. Ce test verifie qu'aucun fichier ne l'oublie — ni ceux
# d'aujourd'hui, ni ceux qu'on ajoutera.
#
#   pwsh -File tests/test-powershell-compatibility.ps1

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$racine = Split-Path $PSScriptRoot -Parent

$script:ko = 0
function ok($libelle, $obtenu, $attendu) {
    $bon = ($obtenu -eq $attendu)
    $marque = if ($bon) { '  ok  ' } else { ' FAIL ' }
    Write-Host "$marque$libelle -> $obtenu$(if (-not $bon) { " (attendu $attendu)" })"
    if (-not $bon) { $script:ko++ }
}

$fichiers = @(Get-ChildItem -Path $racine -Filter '*.ps1' -Recurse -File |
              Where-Object { $_.FullName -notmatch '[\\/]node_modules[\\/]' })
ok 'des scripts a verifier' ($fichiers.Count -gt 0) $true

"--- marqueur d encodage ---"
$sansBom = @()
$neParsePas = @()
foreach ($f in $fichiers) {
    $octets = [System.IO.File]::ReadAllBytes($f.FullName)
    $aBom = ($octets.Length -ge 3 -and $octets[0] -eq 239 -and $octets[1] -eq 187 -and $octets[2] -eq 191)
    if (-not $aBom) { $sansBom += $f.Name }

    $erreurs = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$erreurs)
    if ($erreurs -and $erreurs.Count -gt 0) { $neParsePas += "$($f.Name) : $($erreurs[0].Message)" }
}
ok 'aucun script sans marqueur' ($sansBom -join ', ') ''
ok 'tous parsent'               ($neParsePas -join ' | ') ''

"`n--- le texte accentue survit ---"
# La table des configurations porte des noms accentues qui finissent dans le
# JSON, puis dans la page. C'est la que l'encodage se voit vraiment.
. (Join-Path $racine 'lib-detection.ps1')
$avecAccent = @($ConfigsConnues | Where-Object { $_.nom -match '[^\x00-\x7F]' })
ok 'des noms accentues existent'  ($avecAccent.Count -gt 0) $true
# Mojibake : la marque d'un UTF-8 relu comme de l'ANSI.
$abimes = @($avecAccent | Where-Object { $_.nom -match 'Ã|Â|â€' })
ok 'aucun nom abime'              ($abimes.Count) 0
ok 'les cles SSH gardent leur accent' (@($ConfigsConnues | Where-Object { $_.nom -eq 'Clés SSH' })).Count 1

"`n--- constructions a eviter ---"
# Une apostrophe dans une chaine interpolee passe partout, mais une apostrophe
# typographique mal encodee casse la chaine : on s'en tient a l'apostrophe
# droite dans le code, et on garde les accents pour les donnees affichees.
# Le motif est construit par code de caractere, sinon ce fichier se signalerait
# lui-meme en contenant les caracteres qu'il traque.
$apostrophes = [string][char]0x2019 + [string][char]0x2018
$suspects = @()
foreach ($f in $fichiers) {
    $texte = [System.IO.File]::ReadAllText($f.FullName)
    if ($texte.IndexOfAny($apostrophes.ToCharArray()) -ge 0) { $suspects += $f.Name }
}
ok 'aucune apostrophe typographique' ($suspects -join ', ') ''

# -Include combine a -LiteralPath est ignore par Windows PowerShell 5.1, qui
# rend alors TOUS les fichiers au lieu des seuls fichiers demandes. PowerShell 7
# le respecte, donc le defaut est invisible partout sauf la ou ca compte : sur
# la machine de quelqu'un. C'est le job Windows qui l'a trouve, dans la
# recherche des cles de signature, ou il rapportait le disque entier.
# On analyse l'arbre plutot que le texte : un commentaire qui en parle, comme
# celui-ci, ne doit pas se signaler lui-meme.
$melanges = @()
foreach ($f in $fichiers) {
    $arbre = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$null)
    $appels = $arbre.FindAll({
        param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)
    foreach ($a in $appels) {
        $params = @($a.CommandElements |
            Where-Object { $_ -is [System.Management.Automation.Language.CommandParameterAst] } |
            ForEach-Object { $_.ParameterName.ToLowerInvariant() })
        $litteral = @($params | Where-Object { 'literalpath'.StartsWith($_) -and $_.Length -ge 2 }).Count -gt 0
        $inclut   = @($params | Where-Object { 'include'.StartsWith($_) -and $_.Length -ge 3 }).Count -gt 0
        if ($litteral -and $inclut) { $melanges += "$($f.Name):$($a.Extent.StartLineNumber)" }
    }
}
ok 'aucun -Include avec -LiteralPath' ($melanges -join ', ') ''

Write-Host ""
if ($script:ko -gt 0) { Write-Host "$script:ko EN ECHEC" -ForegroundColor Red; exit 1 }
Write-Host "COMPATIBILITE POWERSHELL 5.1 OK" -ForegroundColor Green
