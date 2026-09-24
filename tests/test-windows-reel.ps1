# Ce que seul un vrai Windows peut dire.
#
# Tout le reste de la suite PowerShell tourne sur Linux, contre des donnees
# fabriquees a la main : cela verifie le raisonnement, jamais Windows. Le
# registre, Get-AppxPackage, WMI et l'encodage d'une console reelle n'y sont
# jamais exerces. Ce fichier lance les scripts pour de vrai, sur la machine
# ou ils sont censes tourner.
#
# Une machine d'integration n'est pas un PC de bureau : on ne sait pas ce qui
# y est installe. Les assertions portent donc sur la FORME de ce qui sort, pas
# sur son contenu — et sur les erreurs qui ne doivent jamais apparaitre.
#
#   pwsh -File tests/test-windows-reel.ps1
#   powershell -File tests/test-windows-reel.ps1     (Windows PowerShell 5.1)

$ErrorActionPreference = 'Stop'
$racine = Split-Path $PSScriptRoot -Parent

$script:ko = 0
function ok($libelle, $obtenu, $attendu) {
    $bon = ($obtenu -eq $attendu)
    $marque = if ($bon) { '  ok  ' } else { ' FAIL ' }
    Write-Host "$marque$libelle -> $obtenu$(if (-not $bon) { " (attendu $attendu)" })"
    if (-not $bon) { $script:ko++ }
}

# Hors Windows ce fichier n'a rien a dire : il sort sans rien pretendre.
$surWindows = $true
if (Get-Variable -Name 'IsWindows' -ErrorAction SilentlyContinue) { $surWindows = $IsWindows }
if (-not $surWindows) {
    Write-Host "Ce test ne vaut que sur Windows : ignore."
    exit 0
}

Write-Host ""
Write-Host "Windows reel — $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)" -ForegroundColor Cyan
Write-Host ""

$bac = Join-Path ([System.IO.Path]::GetTempPath()) ("mpc-win-" + (Get-Random))
New-Item -ItemType Directory -Path $bac -Force | Out-Null
# scan-pc.ps1 depose aussi son resultat a cote de index.html, donc dans le
# depot : on le retire quoi qu'il arrive, il n'a rien a faire dans un commit.
$depose = Join-Path $racine 'resultat-scan.js'

try {
    "--- le scan, pour de vrai ---"
    $sortie = Join-Path $bac 'inventaire.json'
    $journal = Join-Path $bac 'scan.txt'
    & (Join-Path $racine 'scan-pc.ps1') -Sortie $sortie -PasDOuverture *> $journal
    ok 'le scan va au bout'          (Test-Path -LiteralPath $sortie) $true
    $inv = Get-Content -LiteralPath $sortie -Raw -Encoding UTF8 | ConvertFrom-Json
    ok 'il porte son type'           $inv.type 'inventaire-migration-pc'

    # Une machine Windows a forcement des entrees de desinstallation.
    $apps = @($inv.apps)
    ok 'le registre a ete lu'        ($apps.Count -gt 0) $true
    ok 'le systeme est nomme'        ($inv.machine.os -like 'Microsoft Windows*' -or $inv.machine.os -like 'Windows*') $true
    ok 'la machine est nommee'       ([string]::IsNullOrWhiteSpace($inv.machine.nom)) $false

    "`n--- l encodage, la ou il se voit vraiment ---"
    # Un UTF-8 relu comme de l'ANSI laisse ces marques. Sous Windows
    # PowerShell 5.1, c'est le defaut : c'est ici que le BOM se prouve.
    $abimes = @($apps | Where-Object { $_.nom -match 'Ã|Â|â€' })
    ok 'aucun nom abime'             $abimes.Count 0
    $texte = Get-Content -LiteralPath $sortie -Raw -Encoding UTF8
    ok 'le JSON relu ne l est pas non plus' ($texte -match 'Ã¢|Ã©|â€') $false

    "`n--- rien ne s est casse en silence ---"
    $j = Get-Content -LiteralPath $journal -Raw
    # Un detecteur qui tombe est rattrape et annonce ; une trace d'exception
    # non geree, elle, ne doit jamais apparaitre.
    ok 'aucune exception non geree'  ($j -match 'Exception|At line:|ScriptStackTrace') $false

    "`n--- le filtre Xbox ne ramasse pas Windows ---"
    # Une machine d integration n a pas le Game Pass. Tout ce qui sortirait
    # avec cette source serait un composant du systeme mal classe : c est
    # exactement le defaut qu on a corrige sans pouvoir l observer.
    $xbox = @($apps | Where-Object { $_.source -like '*Xbox*' })
    ok 'aucun faux jeu Xbox'         $xbox.Count 0

    "`n--- l editeur du Store est lisible ---"
    $dn = @($apps | Where-Object { $_.editeur -like 'CN=*' -or $_.editeur -like '*, O=*' })
    ok 'aucun certificat recopie'    $dn.Count 0

    "`n--- le materiel, lu par Windows ---"
    $m = $inv.materiel
    $rempli = @('cm','cpu','gpu','ram','ssd') | Where-Object {
        $m.PSObject.Properties[$_] -and -not [string]::IsNullOrWhiteSpace($m.$_) }
    ok 'WMI a repondu'               (@($rempli).Count -gt 0) $true

    "`n--- ce que la page recevra ---"
    ok 'le fichier est pose'         (Test-Path -LiteralPath $depose) $true
    $js = Get-Content -LiteralPath $depose -Raw
    ok 'il pose la variable attendue' ($js.TrimStart([char]0xFEFF).StartsWith('window.MIGRATION_PC_SCAN=')) $true
    $json = $js.Substring($js.IndexOf('=') + 1).TrimEnd()
    $relu = $json.Substring(0, $json.Length - 1) | ConvertFrom-Json
    ok 'et il se relit'              $relu.type 'inventaire-migration-pc'

    "`n--- la verification du PC, pour de vrai ---"
    $verif = Join-Path $bac 'verification.json'
    $jv = Join-Path $bac 'verif.txt'
    & (Join-Path $racine 'verifier-pc.ps1') -Sortie $verif -PasDOuverture *> $jv
    ok 'elle va au bout'             (Test-Path -LiteralPath $verif) $true
    $v = Get-Content -LiteralPath $verif -Raw -Encoding UTF8 | ConvertFrom-Json
    ok 'elle porte son type'         $v.type 'verification-migration-pc'
    ok 'aucune exception non geree'  ((Get-Content -LiteralPath $jv -Raw) -match 'Exception|At line:') $false
    # Le profil d'exemple decrit 18 applications : trouvees ou absentes, elles
    # doivent toutes etre rapportees, sans quoi une a disparu en chemin.
    $profil = Get-Content -LiteralPath (Join-Path $racine 'presets\exemple.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    ok 'chaque application est rapportee' (@($v.trouves).Count + @($v.absents).Count) (@($profil.apps).Count)

    "`n--- le lanceur demarre et rend la main ---"
    # Sans -Console il ouvrirait une fenetre : sur une machine d integration,
    # personne ne la fermerait. En mode texte et sans rien a lire sur l'entree,
    # il doit afficher son menu puis sortir — pas tourner en rond.
    $jl = Join-Path $bac 'lanceur.txt'
    $exe = (Get-Process -Id $PID).Path
    $p = Start-Process -FilePath $exe `
        -ArgumentList @('-NoProfile', '-File', ('"' + (Join-Path $racine 'migration-pc.ps1') + '"'), '-Console') `
        -RedirectStandardOutput $jl -RedirectStandardInput 'NUL' -NoNewWindow -PassThru
    $fini = $p.WaitForExit(60000)
    if (-not $fini) { $p.Kill() }
    ok 'il ne reste pas bloque'      $fini $true
    $l = if (Test-Path -LiteralPath $jl) { Get-Content -LiteralPath $jl -Raw } else { '' }
    ok 'il a liste ses actions'      ($l -match "Cet ordinateur est l'ANCIEN") $true
    ok 'et le parcours complet'      ($l -match 'Par ou commencer') $true
}
finally {
    Remove-Item -LiteralPath $bac -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $depose -Force -ErrorAction SilentlyContinue
}

Write-Host ""
if ($script:ko -gt 0) { Write-Host "$script:ko EN ECHEC" -ForegroundColor Red; exit 1 }
Write-Host "WINDOWS REEL : OPERATIONNEL" -ForegroundColor Green
