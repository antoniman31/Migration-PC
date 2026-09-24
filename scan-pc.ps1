<#
.SYNOPSIS
    Inventorie les logiciels installes sur un PC Windows et produit un fichier JSON
    importable dans la checklist de migration (index.html).

.DESCRIPTION
    Le script interroge quatre sources et fusionne les resultats :
      - winget list        (identifiants d'installation officiels)
      - registre Uninstall (32 et 64 bits, machine et utilisateur)
      - applications du Microsoft Store (paquets APPX)
      - bibliotheques de jeux : Steam, Epic Games, GOG, Xbox
      - variables d'environnement personnalisees de l'utilisateur

    Aucune donnee ne quitte la machine : le script n'envoie rien sur le reseau,
    il ecrit uniquement un fichier JSON local que vous importez vous-meme.

.PARAMETER Sortie
    Chemin du fichier JSON produit. Par defaut inventaire-pc.json dans le dossier courant.

.PARAMETER SansStore
    Ignore les applications du Microsoft Store.

.PARAMETER SansJeux
    Ignore les bibliotheques de jeux : Steam, Epic Games, GOG et Xbox.

.PARAMETER SansVariables
    Ne releve pas les variables d'environnement personnalisees.

.PARAMETER SansOutils
    Ne releve pas les chaines d'outils : SDK Android, WSL, scoop, Chocolatey,
    paquets globaux npm et pip.

.PARAMETER ToutInclure
    Conserve aussi les entrees habituellement filtrees (redistribuables Visual C++,
    mises a jour, composants systeme). Produit une liste beaucoup plus longue.

.EXAMPLE
    .\scan-pc.ps1
    Scan standard, ecrit .\inventaire-pc.json

.EXAMPLE
    .\scan-pc.ps1 -Sortie D:\migration\inventaire.json -ToutInclure

.NOTES
    Windows uniquement. PowerShell 5.1 ou superieur.
    Si l'execution est bloquee :
        powershell -ExecutionPolicy Bypass -File .\scan-pc.ps1
    Les droits administrateur ne sont pas necessaires, mais sans eux certaines
    applications installees par d'autres comptes utilisateurs peuvent manquer.
#>

[CmdletBinding()]
param(
    [switch]$PasDOuverture,
    [string]$Sortie = "inventaire-pc.json",
    [switch]$SansStore,
    [switch]$SansJeux,
    [switch]$SansVariables,
    [switch]$SansConfigs,
    [switch]$SansOutils,
    [switch]$ToutInclure
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
# ---------------------------------------------------------------- detection
# La detection est partagee avec verifier-pc.ps1 et verifier-sauvegardes.ps1 :
# elle vit dans lib-detection.ps1 pour n'exister qu'en un seul exemplaire.
$lib = Join-Path $PSScriptRoot 'lib-detection.ps1'
if (-not (Test-Path $lib)) {
    Write-Error "lib-detection.ps1 est introuvable a cote de ce script. Copiez les deux fichiers ensemble."
    exit 1
}
. $lib

# Ecriture du resultat a cote de la page, et ouverture du navigateur.
$aide = Join-Path $PSScriptRoot 'ecrire-resultat.ps1'
if (Test-Path $aide) { . $aide }

# ---------------------------------------------------------------- execution

Write-Host ""
Write-Host "Inventaire des logiciels installes" -ForegroundColor Cyan
Write-Host "----------------------------------"

$null = Invoke-Detecteur -Nom 'Winget' -Bloc { Read-Winget }
$null = Invoke-Detecteur -Nom 'Registre' -Bloc { Read-Registre }
if (-not $SansStore) { $null = Invoke-Detecteur -Nom 'Store' -Bloc { Read-Store } }
if (-not $SansJeux) {
    $null = Invoke-Detecteur -Nom 'Steam' -Bloc { Read-Steam }
    $null = Invoke-Detecteur -Nom 'Epic' -Bloc { Read-Epic }
    $null = Invoke-Detecteur -Nom 'GOG' -Bloc { Read-GOG }
    $null = Invoke-Detecteur -Nom 'Xbox' -Bloc { Read-Xbox }
}
$variables = if ($SansVariables) { [ordered]@{} } else {
    Invoke-Detecteur -Nom 'variables' -Bloc { Read-Variables }
}

# Les dossiers de configuration des logiciels qu'on vient de detecter :
# installer un logiciel prend une commande, retrouver ses reglages une soiree.
# Le materiel : Windows le connait, autant ne pas le faire saisir a la main.
$materiel = Invoke-Detecteur -Nom 'materiel' -Bloc { Read-Materiel }

# Une machine de developpement porte des chaines d'outils qu'aucun installateur
# n'enregistre : ni le registre, ni winget, ni le Store n'en savent rien. On ne
# les copie pas — elles pesent des dizaines de Go et se retelechargent — on
# emporte la liste et la commande qui remet chaque chose en place.
$outils = @()
if (-not $SansOutils) {
    $outils += @(Invoke-Detecteur -Nom 'SDK Android'      -Bloc { Read-SdkAndroid })
    $outils += @(Invoke-Detecteur -Nom 'WSL'              -Bloc { Read-Wsl })
    $outils += @(Invoke-Detecteur -Nom 'scoop/Chocolatey' -Bloc { Read-GestionnairesPaquets })
    $outils += @(Invoke-Detecteur -Nom 'npm/pip'          -Bloc { Read-OutilsLangages })
}

$configs = if ($SansConfigs) { @() } else {
    @(Invoke-Detecteur -Nom 'configurations' -Bloc { Read-Configs -ClesInstallees @($resultats.Keys) })
}

$apps = $resultats.Values | Sort-Object { $_.nom }

$os = try { (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).Caption } catch { 'Windows' }

$inventaire = [ordered]@{
    type    = 'inventaire-migration-pc'
    version = 1
    genere  = (Get-Date).ToString('o')
    machine = [ordered]@{
        os  = $os
        nom = $env:COMPUTERNAME
    }
    apps    = @($apps)
    # Reprises telles quelles dans les champs prevus par la checklist.
    variables = $variables
    configs   = @($configs)
    materiel  = $materiel
    outils    = @($outils)
}

$json = $inventaire | ConvertTo-Json -Depth 6
Set-Content -Path $Sortie -Value $json -Encoding UTF8

if (Get-Command Write-ResultatPourSite -ErrorAction SilentlyContinue) {
    Write-ResultatPourSite -Donnees $inventaire -DossierScript $PSScriptRoot -NePasOuvrir:$PasDOuverture
}

$avecWinget = @($apps | Where-Object { $_.winget }).Count
$totalGo = Get-Somme $apps 'tailleGo'
$chemin = (Resolve-Path $Sortie).Path

Write-Host ""
Write-Host "$(@($apps).Count) applications retenues, dont $avecWinget avec un identifiant winget." -ForegroundColor Green
if ($totalGo) {
    Write-Host "Taille connue : $([math]::Round($totalGo, 1)) Go — partielle, toutes les sources ne la donnent pas."
}
if (@($configs).Count) {
    $mo = Get-Somme $configs 'tailleMo'
    Write-Host "$(@($configs).Count) dossiers de configuration reperes$(if ($mo) { " ($([math]::Round($mo,0)) Mo)" })."
}
if (@($outils).Count) {
    $familles = @($outils | Group-Object -Property { $_.famille } | Sort-Object Name)
    Write-Host "$(@($outils).Count) outil(s) releve(s) : $(($familles | ForEach-Object { "$($_.Name) ($($_.Count))" }) -join ', ')."
    Write-Host "  Ils ne sont pas copies : la liste et leur commande d installation suffisent."
}
$nombreVariables = Get-Nombre $variables
if ($nombreVariables) {
    Write-Host ('{0} variable(s) d environnement relevee(s).' -f $nombreVariables)
}
Write-Host "Fichier ecrit : $chemin"
Write-Host ""
Write-Host "Etape suivante : ouvrir index.html, cliquer sur Importer, choisir ce fichier."
if (-not $ToutInclure) {
    Write-Host "Une entree manque ? Relancer avec -ToutInclure pour desactiver le filtrage."
}
Write-Host ""
