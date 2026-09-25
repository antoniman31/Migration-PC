# L'aller-retour des configurations, execute pour de vrai.
#
# Ces deux scripts ne font que lire et ecrire des fichiers : contrairement au
# reste de la detection Windows, ils tournent ici entierement. Et restaurer-
# configs.ps1 est le SEUL script du projet qui ecrit sur le disque de
# quelqu'un, donc c'est celui qu'il faut le plus serrer.
#
#   pwsh -File tests/test-configs-aller-retour.ps1

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$racine = Split-Path $PSScriptRoot -Parent
$ToutInclure = $false
$resultats = @{}
. (Join-Path $racine 'scripts/lib-detection.ps1')

$script:ko = 0
function ok($libelle, $obtenu, $attendu) {
    $bon = ($obtenu -eq $attendu)
    $marque = if ($bon) { '  ok  ' } else { ' FAIL ' }
    Write-Host "$marque$libelle -> $obtenu$(if (-not $bon) { " (attendu $attendu)" })"
    if (-not $bon) { $script:ko++ }
}

$T = Join-Path ([System.IO.Path]::GetTempPath()) ("ar-" + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path (Join-Path $T 'profil\.ssh') -Force
$null = New-Item -ItemType Directory -Path (Join-Path $T 'cle') -Force
Set-Content -Path (Join-Path $T 'profil\.ssh\id_ed25519') -Value 'CLE ORIGINALE'
Set-Content -Path (Join-Path $T 'profil\.ssh\known_hosts') -Value 'hotes connus'

# Toutes les racines que la table des configurations sait lire sont deviees
# vers le bac a sable. Sur une vraie machine Windows, en laisser une seule au
# dehors suffirait : le script irait chercher un dossier reel, le copierait, et
# la restauration voudrait le reposer a sa place. Un test n'ecrit pas ailleurs
# que chez lui. %PROGRAMDATA% et %PROGRAMFILES(X86)% comptent : deux entrees de
# la table les utilisent.
$avant = @{
    APPDATA = $env:APPDATA; USERPROFILE = $env:USERPROFILE; LOCALAPPDATA = $env:LOCALAPPDATA
    PROGRAMDATA = $env:ProgramData; PROGRAMFILESX86 = ${env:ProgramFiles(x86)}
}
$env:USERPROFILE  = Join-Path $T 'profil'
$env:APPDATA      = Join-Path $T 'appdata'
$env:LOCALAPPDATA = Join-Path $T 'local'
$env:ProgramData  = Join-Path $T 'programdata'
${env:ProgramFiles(x86)} = Join-Path $T 'programfiles86'
$dest = Join-Path $T 'cle\configs'

try {
    "--- la sauvegarde ---"
    # -Simuler doit tout montrer sans rien ecrire : c'est la premiere chose
    # qu'on conseille de faire, elle doit etre inoffensive.
    & (Join-Path $racine 'scripts/sauvegarder-configs.ps1') -Destination $dest -Simuler *> $null
    ok 'la simulation n ecrit rien'   (Test-Path -LiteralPath $dest) $false

    & (Join-Path $racine 'scripts/sauvegarder-configs.ps1') -Destination $dest *> $null
    $index = Join-Path $dest 'index-configs.json'
    ok 'un index est ecrit'           (Test-Path -LiteralPath $index) $true
    $lu = Get-Content -LiteralPath $index -Raw -Encoding UTF8 | ConvertFrom-Json
    ok 'il porte son type'            $lu.type 'configs-migration-pc'
    $ssh = @($lu.entrees | Where-Object { $_.nom -match 'SSH' })
    ok 'les cles SSH y sont'          $ssh.Count 1
    # Le nom du dossier copie doit correspondre a l'index, sinon la
    # restauration cherchera un dossier qui n'existe pas.
    $copie = Join-Path $dest $ssh[0].dossier
    ok 'le dossier annonce existe'    (Test-Path -LiteralPath $copie) $true
    ok 'les deux fichiers sont copies' (@(Get-ChildItem -LiteralPath $copie -Force)).Count 2
    ok 'le contenu est fidele'        (Get-Content -LiteralPath (Join-Path $copie 'id_ed25519') -Raw -Encoding UTF8).Trim() 'CLE ORIGINALE'

    "`n--- la restauration sur une machine vierge ---"
    Remove-Item -LiteralPath (Join-Path $T 'profil\.ssh') -Recurse -Force
    & (Join-Path $racine 'scripts/restaurer-configs.ps1') -Source $dest -Simuler *> $null
    ok 'la simulation ne restaure rien' (Test-Path -LiteralPath (Join-Path $T 'profil\.ssh')) $false

    & (Join-Path $racine 'scripts/restaurer-configs.ps1') -Source $dest *> $null
    ok 'le dossier est revenu'        (Test-Path -LiteralPath (Join-Path $T 'profil\.ssh')) $true
    ok 'avec son contenu'             (Get-Content -LiteralPath (Join-Path $T 'profil\.ssh\id_ed25519') -Raw -Encoding UTF8).Trim() 'CLE ORIGINALE'
    ok 'et le second fichier'         (Test-Path -LiteralPath (Join-Path $T 'profil\.ssh\known_hosts')) $true
    # Le piege : copier le dossier DANS le dossier, et obtenir .ssh\.ssh.
    ok 'pas de dossier imbrique'      (Test-Path -LiteralPath (Join-Path $T 'profil\.ssh\.ssh')) $false

    "`n--- le refus d ecraser ---"
    Set-Content -Path (Join-Path $T 'profil\.ssh\id_ed25519') -Value 'CLE DU NOUVEAU PC'
    & (Join-Path $racine 'scripts/restaurer-configs.ps1') -Source $dest *> $null
    # Sans -Remplacer, rien ne doit bouger : c'est tout l'interet du defaut.
    ok 'le fichier en place est intact' (Get-Content -LiteralPath (Join-Path $T 'profil\.ssh\id_ed25519') -Raw -Encoding UTF8).Trim() 'CLE DU NOUVEAU PC'

    "`n--- -Remplacer garde une porte de sortie ---"
    & (Join-Path $racine 'scripts/restaurer-configs.ps1') -Source $dest -Remplacer *> $null
    ok 'la sauvegarde a ete posee'    (Get-Content -LiteralPath (Join-Path $T 'profil\.ssh\id_ed25519') -Raw -Encoding UTF8).Trim() 'CLE ORIGINALE'
    $misDeCote = @(Get-ChildItem -LiteralPath (Join-Path $T 'profil') -Force -Directory |
                   Where-Object { $_.Name -like '.ssh.avant-migration-*' })
    ok 'l ancien est mis de cote'     $misDeCote.Count 1
    # Sans ca, l'operation serait irreversible : c'est la condition pour qu'un
    # script qui ecrase soit acceptable.
    ok 'et reste lisible'             (Get-Content -LiteralPath (Join-Path $misDeCote[0].FullName 'id_ed25519') -Raw -Encoding UTF8).Trim() 'CLE DU NOUVEAU PC'

    "`n--- ce qu une regle laisse derriere elle ---"
    # La table copiait des dossiers entiers : une entree « .gradle » emportait
    # dix Go de caches regenerables pour deux kilo-octets de reglages. On
    # construit ici le meme cas en petit, et on lance le vrai script.
    $g = Join-Path $T 'profil\.gradle'
    New-Item -ItemType Directory -Path (Join-Path $g 'caches\modules-2\files') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $g 'daemon\8.7') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $g 'init.d') -Force | Out-Null
    Set-Content -Path (Join-Path $g 'gradle.properties') -Value 'org.gradle.jvmargs=-Xmx4g'
    Set-Content -Path (Join-Path $g 'init.d\perso.gradle') -Value '// mon init'
    # Assez gros pour que les tailles se distinguent : une assertion qui compare
    # 0 a 0 ne prouve rien.
    Set-Content -Path (Join-Path $g 'init.d\gros-utile.gradle') -Value ('u' * 400KB) -NoNewline
    Set-Content -Path (Join-Path $g 'caches\modules-2\files\gros.bin') -Value ('x' * 4MB) -NoNewline
    Set-Content -Path (Join-Path $g 'daemon\8.7\daemon.log') -Value ('l' * 1MB) -NoNewline

    $destG = Join-Path $T 'cle\avec-exclusions'
    & (Join-Path $racine 'scripts/sauvegarder-configs.ps1') -Destination $destG *> $null
    $idxG = Get-Content -LiteralPath (Join-Path $destG 'index-configs.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $eG = @($idxG.entrees | Where-Object { $_.nom -eq 'Gradle' })
    ok 'l entree Gradle est reperee'  $eG.Count 1
    $copieG = Join-Path $destG $eG[0].dossier
    ok 'les reglages sont copies'     (Test-Path -LiteralPath (Join-Path $copieG 'gradle.properties')) $true
    ok 'un sous-dossier utile aussi'  (Test-Path -LiteralPath (Join-Path $copieG 'init.d\perso.gradle')) $true
    ok 'les caches sont laisses'      (Test-Path -LiteralPath (Join-Path $copieG 'caches')) $false
    ok 'le daemon aussi'              (Test-Path -LiteralPath (Join-Path $copieG 'daemon')) $false
    # La taille annoncee doit etre celle de ce qui part, pas celle du dossier :
    # annoncer 10 Go pour en ecrire 2 Mo se remarquerait, l inverse se
    # remarquerait au pire moment.
    $octetsCopies = (Get-ChildItem -LiteralPath $copieG -Recurse -File -Force | Measure-Object -Property Length -Sum).Sum
    ok 'la taille annoncee est celle du copie' `
        ([math]::Round($eG[0].tailleMo, 1)) ([math]::Round($octetsCopies / 1MB, 1))
    # Et elle est bien plus petite que le dossier d origine, sinon la
    # comparaison ci-dessus pourrait etre juste sans que rien ne soit exclu.
    $octetsSource = (Get-ChildItem -LiteralPath $g -Recurse -File -Force | Measure-Object -Property Length -Sum).Sum
    ok 'et bien plus petite que la source' (($octetsCopies * 4) -lt $octetsSource) $true
    ok 'l index dit ce qui a ete ecarte' (@($eG[0].exclu) -contains 'caches') $true

    # Et la restauration repose exactement ce qui a ete emporte, sans inventer.
    Remove-Item -LiteralPath $g -Recurse -Force
    & (Join-Path $racine 'scripts/restaurer-configs.ps1') -Source $destG *> $null
    ok 'les reglages reviennent'      (Get-Content -LiteralPath (Join-Path $g 'gradle.properties') -Raw -Encoding UTF8).Trim() 'org.gradle.jvmargs=-Xmx4g'
    ok 'les caches ne reviennent pas' (Test-Path -LiteralPath (Join-Path $g 'caches')) $false
    Remove-Item -LiteralPath $g -Recurse -Force

    "`n--- un dossier dont le nom porte une version ---"
    # Android Studio et les IDE JetBrains rangent leurs reglages dans un dossier
    # qui porte leur version : sans joker, la table ne trouvait rien.
    $as = Join-Path $T 'appdata\Google\AndroidStudio2024.2'
    New-Item -ItemType Directory -Path $as -Force | Out-Null
    Set-Content -Path (Join-Path $as 'keymap.xml') -Value '<raccourcis/>'
    $resolus = @(Expand-CheminModele -Modele '%APPDATA%\Google\AndroidStudio*')
    ok 'le joker trouve le dossier'   $resolus.Count 1
    # Le modele reconstruit est ce qui permettra de restaurer ailleurs : s il
    # gardait le joker, la restauration ne saurait pas ou reposer le dossier.
    ok 'et reconstruit un modele sans joker' $resolus[0].modele '%APPDATA%\Google\AndroidStudio2024.2'
    Remove-Item -LiteralPath $as -Recurse -Force

    "`n--- le nouveau PC n a pas le meme nom d utilisateur ---"
    # C'est le cas normal d'une migration, pas un cas tordu. L'index gardait
    # « C:\Users\<ancien nom>\.ssh » : restaurer dessus creait ce dossier sur
    # le PC neuf, sous un profil que personne n'utilise, et l'annoncait en vert.
    $neuf = Join-Path $T 'profil-du-neuf'
    $null = New-Item -ItemType Directory -Path $neuf -Force
    $ancienProfil = $env:USERPROFILE
    # Les blocs precedents ont deja mis un .ssh de cote ici : ce qu'on verifie,
    # c'est qu'aucun NOUVEAU deplacement n'a lieu sous l'ancien profil.
    $avantCote = @(Get-ChildItem -LiteralPath $ancienProfil -Filter '.ssh.avant-migration-*' -Force -ErrorAction SilentlyContinue).Count
    $env:USERPROFILE = $neuf
    try {
        & (Join-Path $racine 'scripts/restaurer-configs.ps1') -Source $dest *> $null
        ok 'les cles arrivent chez le nouvel utilisateur' `
            (Test-Path -LiteralPath (Join-Path $neuf '.ssh\id_ed25519')) $true
        ok 'avec le bon contenu' `
            (Get-Content -LiteralPath (Join-Path $neuf '.ssh\id_ed25519') -Raw -Encoding UTF8).Trim() 'CLE ORIGINALE'
        # Et surtout : rien n'a ete ecrit sous le profil de l'ancienne machine.
        $apresCote = @(Get-ChildItem -LiteralPath $ancienProfil -Filter '.ssh.avant-migration-*' -Force -ErrorAction SilentlyContinue).Count
        ok 'l ancien profil n est pas touche' $apresCote $avantCote
    } finally {
        $env:USERPROFILE = $ancienProfil
    }

    "`n--- un index d avant, sans modele ---"
    # Une sauvegarde faite par la version precedente n'a pas de champ
    # « modele » : elle doit continuer a se restaurer, sur son chemin d'origine.
    $vieux = Join-Path $T 'cle\vieux'
    $null = New-Item -ItemType Directory -Path (Join-Path $vieux 'Truc') -Force
    Set-Content -Path (Join-Path $vieux 'Truc\reglages.txt') -Value 'ANCIEN FORMAT'
    $cible = Join-Path $T 'cible-heritee'
    $vieilIndex = [ordered]@{
        type = 'configs-migration-pc'; version = 1; genere = (Get-Date).ToString('o')
        machine = 'ANCIEN-PC'
        entrees = @([ordered]@{ nom = 'Truc'; origine = $cible; dossier = 'Truc'; quoi = ''; tailleMo = 0 })
    }
    Set-Content -LiteralPath (Join-Path $vieux 'index-configs.json') -Value ($vieilIndex | ConvertTo-Json -Depth 6) -Encoding UTF8
    & (Join-Path $racine 'scripts/restaurer-configs.ps1') -Source $vieux *> $null
    ok 'un index sans modele se restaure encore' `
        (Get-Content -LiteralPath (Join-Path $cible 'reglages.txt') -Raw -Encoding UTF8).Trim() 'ANCIEN FORMAT'

    "`n--- ce qu il refuse de faire ---"
    $vide = Join-Path $T 'pas-un-dossier-de-sauvegarde'
    $null = New-Item -ItemType Directory -Path $vide -Force
    $code = 0
    try { & (Join-Path $racine 'scripts/restaurer-configs.ps1') -Source $vide *> $null } catch { $code = 1 }
    # Un dossier sans index n'a pas ete produit par nous : on ne devine pas.
    ok 'un dossier sans index est refuse' ($code -eq 1 -or $LASTEXITCODE -ne 0) $true

    $code = 0
    try { & (Join-Path $racine 'scripts/restaurer-configs.ps1') -Source (Join-Path $T 'nexiste-pas') *> $null } catch { $code = 1 }
    ok 'une source absente est refusee'   ($code -eq 1 -or $LASTEXITCODE -ne 0) $true
}
finally {
    $env:APPDATA = $avant.APPDATA; $env:USERPROFILE = $avant.USERPROFILE
    $env:LOCALAPPDATA = $avant.LOCALAPPDATA; $env:ProgramData = $avant.PROGRAMDATA
    ${env:ProgramFiles(x86)} = $avant.PROGRAMFILESX86
    Remove-Item -LiteralPath $T -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
if ($script:ko -gt 0) { Write-Host "$script:ko EN ECHEC" -ForegroundColor Red; exit 1 }
Write-Host "ALLER-RETOUR DES CONFIGURATIONS OPERATIONNEL" -ForegroundColor Green
