# Execute reellement verifier-sauvegardes.ps1 sur une arborescence construite
# pour l'occasion. Contrairement aux autres scripts du projet, celui-ci ne
# touche ni au registre ni aux paquets : il ne fait que lire des fichiers, donc
# il tourne vraiment ici, et ce test constate son comportement au lieu de le
# simuler.
#
#   pwsh -File tests/test-sauvegardes.ps1
$ErrorActionPreference = 'Stop'
$script:ko = 0
function ok($l, $a, $b) {
    if ($a -eq $b) { "  ok   $l -> $a" } else { "  FAIL $l -> $a (attendu $b)"; $script:ko++ }
}

$racine = Split-Path $PSScriptRoot -Parent
$base = Join-Path ([System.IO.Path]::GetTempPath()) "mpc-sv-$PID"
$src = Join-Path $base 'src'
$dst = Join-Path $base 'dst'

function Ecrire($chemin, $octets) {
    $d = Split-Path $chemin -Parent
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    $buf = New-Object byte[] $octets
    (New-Object Random).NextBytes($buf)
    [IO.File]::WriteAllBytes($chemin, $buf)
}

try {
    # --- arborescence -------------------------------------------------
    1..5 | ForEach-Object { Ecrire (Join-Path $src "Documents/f$_.bin") 20000 }
    Ecrire (Join-Path $src 'Bureau/note.txt') 5000
    Ecrire (Join-Path $src 'Cles/id_ed25519') 400
    New-Item -ItemType Directory -Path (Join-Path $src 'Vide') -Force | Out-Null

    # copie fidele
    Copy-Item (Join-Path $src 'Documents') (Join-Path $dst 's1') -Recurse -Force
    # copie tronquee : meme nombre de fichiers, taille differente
    New-Item -ItemType Directory -Path (Join-Path $dst 's2') -Force | Out-Null
    Ecrire (Join-Path $dst 's2/note.txt') 3000
    # copie vide : le dossier existe mais rien dedans
    New-Item -ItemType Directory -Path (Join-Path $dst 's5') -Force | Out-Null

    # --- profil -------------------------------------------------------
    # %MPCSV% passe le filtre « ressemble a un chemin » et s'expanse sur toute
    # plateforme, ce qui permet d'eprouver le script de bout en bout.
    $env:MPCSV = $base
    $profil = [ordered]@{
        meta = [ordered]@{ version = 1; nom = 'Test' }
        cats = @{}; npc = @(); apps = @(); pwa = @(); ordre = @(); requetes = @{}
        data = @(
            [ordered]@{ id = 's1'; n = 'Documents';  p = '%MPCSV%/src/Documents'; note = ''; pr = 'high' },
            [ordered]@{ id = 's2'; n = 'Bureau';     p = '%MPCSV%/src/Bureau';    note = ''; pr = 'high' },
            [ordered]@{ id = 's5'; n = 'Cles';       p = '%MPCSV%/src/Cles';      note = ''; pr = 'high' },
            [ordered]@{ id = 's6'; n = 'Licences';   p = 'Courriels et comptes';  note = ''; pr = 'high' },
            [ordered]@{ id = 's9'; n = 'Vide';       p = '%MPCSV%/src/Vide';      note = ''; pr = 'med' },
            [ordered]@{ id = 's11'; n = 'Inexistant'; p = '%MPCSV%/src/Jamais';   note = ''; pr = 'ok' },
            [ordered]@{ id = 's12'; n = 'Deux';      p = '%MPCSV%/src/Documents et %MPCSV%/src/Bureau'; note = ''; pr = 'med' }
        )
    }
    $fProfil = Join-Path $base 'profil.json'
    Set-Content -Path $fProfil -Value ($profil | ConvertTo-Json -Depth 8) -Encoding UTF8
    $fSortie = Join-Path $base 'rapport.json'

    # --- execution ----------------------------------------------------
    & (Join-Path $racine 'verifier-sauvegardes.ps1') -Destination $dst -Profil $fProfil -Sortie $fSortie | Out-Null
    $r = Get-Content $fSortie -Raw -Encoding UTF8 | ConvertFrom-Json

    "--- rapport produit ---"
    ok 'type correct'          $r.type 'sauvegardes-migration-pc'
    ok 'destination reportee'  $r.destination $dst
    ok 'tous les elements'     $r.elements.Count 7

    $etat = @{}
    foreach ($e in $r.elements) { $etat[$e.id] = $e.etat }

    "--- etats detectes ---"
    ok 'copie fidele -> ok'              $etat['s1'] 'ok'
    ok 'copie tronquee -> ecart-taille'  $etat['s2'] 'ecart-taille'
    ok 'copie vide -> incomplet'         $etat['s5'] 'incomplet'
    ok 'texte libre -> non-verifiable'   $etat['s6'] 'non-verifiable'
    ok 'source vide -> rien a sauver'    $etat['s9'] 'rien-a-sauvegarder'
    ok 'source absente -> rien a sauver' $etat['s11'] 'rien-a-sauvegarder'
    ok 'sans copie -> manquant'          $etat['s12'] 'manquant'

    "--- decoupage des chemins multiples ---"
    $deux = $r.elements | Where-Object { $_.id -eq 's12' }
    ok 'deux chemins traites'  $deux.chemins.Count 2

    "--- mesures ---"
    $doc = $r.elements | Where-Object { $_.id -eq 's1' }
    ok 'fichiers comptes a la source' $doc.chemins[0].fichiersSource 5
    ok 'fichiers comptes dans la copie' $doc.chemins[0].fichiersCopie 5
    ok 'tailles identiques'    $doc.chemins[0].octetsSource $doc.chemins[0].octetsCopie
    $bur = $r.elements | Where-Object { $_.id -eq 's2' }
    ok 'ecart de taille mesure' ($bur.chemins[0].ecartParCent -gt 2) $true

    "--- resume et progression ---"
    ok 'un seul conforme'      $r.resume.conformes 1
    ok 'trois a revoir'        $r.resume.problemes 3
    ok 'un non verifiable'     $r.resume.nonVerifiables 1
    # Le rapport est aussi une progression importable telle quelle.
    ok 'seul le conforme est coche' ($r.state.checked.PSObject.Properties.Name -join ',') 's1'
    ok 'une date accompagne la coche' ($null -ne $r.state.dates.s1) $true

    "--- tolerance reglable ---"
    $f2 = Join-Path $base 'rapport2.json'
    & (Join-Path $racine 'verifier-sauvegardes.ps1') -Destination $dst -Profil $fProfil -Sortie $f2 -ToleranceParCent 90 | Out-Null
    $r2 = Get-Content $f2 -Raw -Encoding UTF8 | ConvertFrom-Json
    $etat2 = @{}
    foreach ($e in $r2.elements) { $etat2[$e.id] = $e.etat }
    ok 'tolerance large accepte l ecart' $etat2['s2'] 'ok'

    "--- un profil incomplet ne fait pas tout tomber ---"
    # Un profil ecrit a la main peut omettre un champ. Sous Set-StrictMode,
    # lire une propriete absente est fatal : un seul element incomplet
    # arretait la verification de tous les autres.
    $fTrou = Join-Path $base 'profil-troue.json'
    $troue = @{
        meta = @{ nom = 'T' }; cats = @{}; npc = @(); apps = @(); pwa = @(); ordre = @()
        data = @(
            @{ id = 't1'; n = 'Sans chemin'; pr = 'high' },
            @{ id = 't2'; pr = 'high'; p = (Join-Path $src 'Documents') },
            @{ n = 'Sans identifiant'; p = 'C:\\nexistepas'; pr = 'ok' }
        )
    }
    Set-Content -Path $fTrou -Value ($troue | ConvertTo-Json -Depth 6) -Encoding UTF8
    $fr = Join-Path $base 'rapport-troue.json'
    & (Join-Path $racine 'verifier-sauvegardes.ps1') -Destination $dst -Profil $fTrou -Sortie $fr | Out-Null
    $rt = Get-Content $fr -Raw -Encoding UTF8 | ConvertFrom-Json
    ok 'les trois elements sont rapportes' @($rt.elements).Count 3
    $sansChemin = $rt.elements | Where-Object { $_.id -eq 't1' }
    ok 'celui sans chemin est dit non verifiable' $sansChemin.etat 'non-verifiable'
    ok 'et on explique pourquoi'   $sansChemin.detail 'aucun chemin declare'
    $sansNom = $rt.elements | Where-Object { $_.id -eq 't2' }
    ok 'celui sans nom garde un libelle' $sansNom.nom 'Element sans nom'

    "--- destination introuvable ---"
    $code = 0
    try {
        & (Join-Path $racine 'verifier-sauvegardes.ps1') -Destination (Join-Path $base 'nexistepas') -Profil $fProfil -Sortie (Join-Path $base 'r3.json') 2>$null | Out-Null
    } catch { $code = 1 }
    ok 'echoue proprement' ($code -eq 1 -or $LASTEXITCODE -ne 0) $true

} finally {
    Remove-Item $base -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item Env:\MPCSV -ErrorAction SilentlyContinue
}

if ($script:ko) { "`n$($script:ko) TEST(S) EN ECHEC"; exit 1 } else { "`nVERIFICATION DES SAUVEGARDES OPERATIONNELLE" }
