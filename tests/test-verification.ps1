# Tests du rapprochement entre ce qui est detecte et ce que le profil decrit.
# La detection elle-meme (registre, Store, lanceurs) n'existe pas hors Windows :
# on simule ses resultats et on verifie ce que le script en fait.
#   pwsh -File tests/test-verification.ps1
$ToutInclure = $false
$resultats = @{}
. "$PSScriptRoot/../lib-detection.ps1"

$script:ko = 0
function ok($l, $a, $b) {
    if ($a -eq $b) { "  ok   $l -> $a" } else { "  FAIL $l -> $a (attendu $b)"; $script:ko++ }
}

"--- index de rapprochement ---"
# On rejoue la construction des index du script, sur un parc simule.
$installes = @(
    [ordered]@{ nom = '7-Zip 24.08 (x64)'; winget = '7zip.7zip';     version = '24.08' },
    [ordered]@{ nom = 'Mozilla Firefox';   winget = 'Mozilla.Firefox'; version = '142.0' },
    [ordered]@{ nom = 'Un outil maison';   winget = '';               version = '1.0' },
    [ordered]@{ nom = 'Steam';             winget = '';               version = '' }
)
$parWinget = @{}; $parCle = @{}
foreach ($a in $installes) {
    if ($a.winget) { $k = $a.winget.ToLowerInvariant(); if (-not $parWinget.ContainsKey($k)) { $parWinget[$k] = $a } }
    $c = Get-Cle -Nom $a.nom
    if ($c -and -not $parCle.ContainsKey($c)) { $parCle[$c] = $a }
}
ok 'index winget rempli'    $parWinget.Count 2
ok 'index par nom rempli'   $parCle.Count 4

"--- correspondance par identifiant winget ---"
ok 'casse ignoree'          $parWinget.ContainsKey('7zip.7zip') $true
ok 'identifiant absent'     $parWinget.ContainsKey('inconnu.app') $false
$e = $parWinget['mozilla.firefox']
ok 'bonne entree trouvee'   $e.nom 'Mozilla Firefox'
ok 'version disponible'     $e.version '142.0'

"--- correspondance par nom ---"
# Le nom du profil et celui du registre different souvent par la version
# et l'architecture : c'est tout l'interet de la normalisation.
ok '7-Zip du profil trouve' $parCle.ContainsKey((Get-Cle -Nom '7-Zip')) $true
ok 'Steam trouve'           $parCle.ContainsKey((Get-Cle -Nom 'Steam')) $true
ok 'un absent reste absent' $parCle.ContainsKey((Get-Cle -Nom 'Blender')) $false

"--- ce que produit le rapprochement ---"
$profil = @(
    [ordered]@{ id = 'a1'; n = '7-Zip';    w = '7zip.7zip' },
    [ordered]@{ id = 'a2'; n = 'Steam';    w = 'Valve.Steam' },
    [ordered]@{ id = 'a3'; n = 'Blender';  w = 'BlenderFoundation.Blender' },
    [ordered]@{ id = 'a4'; n = 'Un outil maison' }
)
function Rapprocher($profil, $approx) {
    $t = @(); $abs = @()
    foreach ($el in $profil) {
        $corr = $null; $conf = ''
        $w = $null
        if ($el.Contains('w')) { $w = $el['w'] }
        if ($w) {
            $k = ([string]$w).ToLowerInvariant()
            if ($parWinget.ContainsKey($k)) { $corr = $parWinget[$k]; $conf = 'sure' }
        }
        if (-not $corr -and $approx) {
            $c = Get-Cle -Nom $el['n']
            if ($c -and $parCle.ContainsKey($c)) { $corr = $parCle[$c]; $conf = 'approximative' }
        }
        if ($corr) { $t += [ordered]@{ id = $el['id']; confiance = $conf } } else { $abs += $el['id'] }
    }
    return @{ trouves = $t; absents = $abs }
}

$strict = Rapprocher $profil $false
ok 'sans -NomsApproximatifs : 1 trouve' $strict.trouves.Count 1
ok '  et c est une correspondance sure' $strict.trouves[0].confiance 'sure'
ok '  Steam non trouve sans son id'     ($strict.absents -contains 'a2') $true

$large = Rapprocher $profil $true
ok 'avec -NomsApproximatifs : 3 trouves' $large.trouves.Count 3
ok '  Blender reste absent'              ($large.absents -contains 'a3') $true
$approx = @($large.trouves | Where-Object { $_.confiance -eq 'approximative' })
ok '  2 correspondances approximatives'  $approx.Count 2

"--- le vrai script, de bout en bout ---"
# Les blocs ci-dessus rejouent la logique de rapprochement : ils verifient le
# raisonnement, pas le fichier. Un profil incomplet ne les atteint donc jamais,
# alors que c'est la que le script tombait — lire une propriete absente est
# fatal sous Set-StrictMode. On lance ici le script lui-meme.
$racineP = Split-Path $PSScriptRoot -Parent
$bac = Join-Path ([System.IO.Path]::GetTempPath()) ("mpc-vpc-" + (Get-Random))
New-Item -ItemType Directory -Path $bac -Force | Out-Null
try {
    $fp = Join-Path $bac 'profil-troue.json'
    $troue = @{
        meta = @{ nom = 'T' }; cats = @{}; npc = @(); pwa = @(); data = @(); ordre = @()
        apps = @(
            @{ id = 'a1'; n = '7-Zip'; c = 'x'; src = 's'; w = '7zip.7zip'; p = 'high'; t = 5; d = 'd' },
            @{ id = 'a2'; c = 'x'; src = 's'; p = 'high'; t = 5; d = 'd' },
            @{ n = 'Sans identifiant'; c = 'x'; src = 's'; p = 'ok'; t = 1; d = 'd' }
        )
    }
    Set-Content -Path $fp -Value ($troue | ConvertTo-Json -Depth 6) -Encoding UTF8
    $fs = Join-Path $bac 'verif.json'
    & (Join-Path $racineP 'verifier-pc.ps1') -Profil $fp -Sortie $fs -PasDOuverture | Out-Null
    ok 'le script va au bout'        (Test-Path $fs) $true
    $rv = Get-Content $fs -Raw | ConvertFrom-Json
    ok 'les trois elements sont vus' (@($rv.trouves).Count + @($rv.absents).Count) 3
    $sansNom = @($rv.absents | Where-Object { $_.id -eq 'a2' })
    ok 'celui sans nom garde un libelle' $sansNom[0].nom 'Element sans nom'
} finally {
    Remove-Item $bac -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $racineP 'resultat-scan.js') -Force -ErrorAction SilentlyContinue
}

"--- serialisation ---"
$v = [ordered]@{
    type = 'verification-migration-pc'; version = 1; genere = (Get-Date).ToString('o')
    machine = [ordered]@{ os = 'Windows 11'; nom = 'NOUVEAU-PC' }
    profil  = [ordered]@{ fichier = 'exemple.json'; nom = 'Test' }
    trouves = @([ordered]@{ id = 'a1'; nom = '7-Zip'; detecte = '7-Zip 24.08 (x64)'
                            version = '24.08'; source = 'registre, winget'
                            raison = 'identifiant winget 7zip.7zip'; confiance = 'sure' })
    absents = @([ordered]@{ id = 'a3'; nom = 'Blender' })
}
$f = Join-Path ([System.IO.Path]::GetTempPath()) "verif-test.json"
Set-Content -Path $f -Value ($v | ConvertTo-Json -Depth 6) -Encoding UTF8
$relu = Get-Content $f -Raw | ConvertFrom-Json
ok 'type correct'            $relu.type 'verification-migration-pc'
ok 'trouves serialises'      $relu.trouves.Count 1
ok 'raison conservee'        $relu.trouves[0].raison 'identifiant winget 7zip.7zip'
ok 'confiance conservee'     $relu.trouves[0].confiance 'sure'
ok 'absents serialises'      $relu.absents.Count 1
Remove-Item $f -Force

if ($script:ko) { "`n$($script:ko) TEST(S) EN ECHEC"; exit 1 } else { "`nRAPPROCHEMENT OPERATIONNEL" }
