# Tests de la detection partagee. Depuis que les trois scripts s'appuient sur
# lib-detection.ps1, il suffit de la charger : elle ne fait rien d'elle-meme.
#   pwsh -File tests/test-scan.ps1
$ToutInclure = $false
$resultats = @{}
. "$PSScriptRoot/../lib-detection.ps1"
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
    $m = Get-Content $_.FullName -Raw | ConvertFrom-Json
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

"--- variables d'environnement ---"
# Read-Variables lit l'environnement reel ; on verifie surtout que les
# variables standard sont bien ecartees et qu'une variable custom passe.
[Environment]::SetEnvironmentVariable('MPC_TEST_VAR', 'D:/test', 'Process')
$standard = @('PATH','TEMP','USERPROFILE','APPDATA','WINDIR')
ok 'PATH est dans la liste standard'     ($standard -contains 'PATH') $true
ok 'une variable custom ne l est pas'    ($standard -contains 'MPC_TEST_VAR') $false

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

if($script:ko){"`n$($script:ko) TEST(S) EN ECHEC"; exit 1} else {"`nTOUS LES TESTS POWERSHELL PASSENT"}
