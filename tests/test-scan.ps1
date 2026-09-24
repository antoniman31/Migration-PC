# Tests du scanner : charge les fonctions de scan-pc.ps1 sans lancer le scan reel.
#   pwsh -File tests/test-scan.ps1
$src = Get-Content "$PSScriptRoot/../scan-pc.ps1" -Raw
$coupe = $src.IndexOf('# ---------------------------------------------------------------- execution')
if ($coupe -lt 0) { Write-Error "marqueur d'execution introuvable dans scan-pc.ps1"; exit 1 }
$corps = $src.Substring(0, $coupe) -replace '\[CmdletBinding\(\)\]', ''
$corps = [regex]::Replace($corps, 'param\(\r?\n(    .*\r?\n)+\)', '$ToutInclure = $false')
Invoke-Expression $corps
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

"--- JSON produit ---"
$inv=[ordered]@{type='inventaire-migration-pc';version=1;genere=(Get-Date).ToString('o');
  machine=[ordered]@{os='Windows 11 Pro';nom='TEST'};apps=@($resultats.Values | Sort-Object {$_.nom})}
$j=$inv | ConvertTo-Json -Depth 6
Set-Content -Path (Join-Path ([System.IO.Path]::GetTempPath()) "inv-test.json") -Value $j -Encoding UTF8
$relu = Get-Content (Join-Path ([System.IO.Path]::GetTempPath()) "inv-test.json") -Raw | ConvertFrom-Json
ok 'type'                   $relu.type 'inventaire-migration-pc'
ok 'apps serialisees'       $relu.apps.Count 4
ok 'champs presents'        ($null -ne $relu.apps[0].nom -and $null -ne $relu.apps[0].cat) $true

if($script:ko){"`n$($script:ko) TEST(S) EN ECHEC"; exit 1} else {"`nTOUS LES TESTS POWERSHELL PASSENT"}
